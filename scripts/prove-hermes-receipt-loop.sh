#!/usr/bin/env bash
set -euo pipefail

ROOT="${AI_RESEARCH_ROOT:-/mnt/develop/AI_Research}"
ENV_FILE="${DOCKER_COMPOSE_ENV_FILE:-$ROOT/docker-compose.env}"
TIMEOUT_SECONDS="${HERMES_RECEIPT_PROOF_TIMEOUT_SECONDS:-120}"
POLL_SECONDS="${HERMES_RECEIPT_PROOF_POLL_SECONDS:-3}"
TARGET_URL="${HERMES_RECEIPT_PROOF_TARGET_URL:-https://example.com}"

ok() { printf 'PASS  %s\n' "$1"; }
warn() { printf 'WARN  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; exit 1; }
info() { printf 'INFO  %s\n' "$1"; }

compose() {
  docker compose --env-file "$ENV_FILE" "$@"
}

if [ ! -d "$ROOT" ]; then
  fail "workspace root missing: $ROOT"
fi

if [ ! -f "$ENV_FILE" ]; then
  fail "docker compose env file missing: $ENV_FILE"
fi

if ! command -v docker >/dev/null 2>&1; then
  fail "docker missing from PATH"
fi

printf 'Hermes receipt bridge proof\n'
printf 'Root: %s\n' "$ROOT"
printf 'Env: %s\n\n' "$ENV_FILE"

viewer_cid="$(compose ps -q offensive-research-portal 2>/dev/null || true)"
gateway_cid="$(compose ps -q hermes-gateway 2>/dev/null || true)"

if [ -z "$viewer_cid" ]; then
  fail "offensive-research-portal is not running or Docker is not accessible; start/check with docker compose --env-file docker-compose.env up -d offensive-research-portal hermes-gateway"
fi

if [ -z "$gateway_cid" ]; then
  fail "hermes-gateway is not running or Docker is not accessible; start/check with docker compose --env-file docker-compose.env up -d offensive-research-portal hermes-gateway"
fi

poll_enabled="$(docker exec "$gateway_cid" sh -lc 'printf %s "${ORP_TASK_POLL_ENABLED:-false}"' 2>/dev/null || true)"
mode="$(docker exec "$gateway_cid" sh -lc 'printf %s "${ORP_TASK_EXECUTION_MODE:-receipt}"' 2>/dev/null || true)"

if [ "$poll_enabled" != "true" ]; then
  fail "ORP_TASK_POLL_ENABLED is not true in hermes-gateway"
fi

if [ "$mode" != "receipt" ]; then
  fail "ORP_TASK_EXECUTION_MODE is '$mode', expected 'receipt' for this safe proof"
fi

ok "Hermes gateway is configured for receipt-mode task polling"

create_output="$(docker exec \
  -e PROOF_TARGET_URL="$TARGET_URL" \
  "$viewer_cid" \
  node -e '
const user = process.env.VIEWER_BASIC_AUTH_USER || "";
const pass = process.env.VIEWER_BASIC_AUTH_PASSWORD || "";
const headers = { "content-type": "application/json" };
if (user || pass) headers.authorization = "Basic " + Buffer.from(`${user}:${pass}`).toString("base64");
const proofId = new Date().toISOString();
const body = {
  title: `Local Hermes gateway bridge proof ${proofId}`,
  instructions: "Prove the local gateway can claim a task, post events, submit a generated report, and update task status. Do not perform external testing.",
  target_url: process.env.PROOF_TARGET_URL || "https://example.com",
  target_type: "webapp",
  risk_level: "low",
  allowed_actions: "claim,event,report,status",
  requires_approval: false,
};
fetch("http://127.0.0.1:3000/api/tasks", { method: "POST", headers, body: JSON.stringify(body) })
  .then(async (response) => {
    const text = await response.text();
    let data = {};
    try { data = JSON.parse(text); } catch {}
    if (!response.ok || !data.id) {
      console.error(JSON.stringify({ status: response.status, error: data.error || text.slice(0, 240) }));
      process.exit(1);
    }
    console.log(JSON.stringify({ id: data.id, status: data.status, approval_status: data.approval_status }));
  })
  .catch((error) => { console.error(error.message); process.exit(1); });
' 2>/dev/null)" || fail "failed to create receipt proof task"

task_id="$(printf '%s' "$create_output" | node -e 'let s=""; process.stdin.on("data", d => s += d); process.stdin.on("end", () => { const data = JSON.parse(s); process.stdout.write(data.id || ""); });')"

if [ -z "$task_id" ]; then
  fail "created task did not return an id"
fi

ok "Created receipt proof task $task_id"
info "Restarting hermes-gateway so the runner polls immediately"
compose restart hermes-gateway >/dev/null

start_epoch="$(date +%s)"
last_summary=""

while true; do
  summary="$(docker exec \
    -e TASK_ID="$task_id" \
    "$viewer_cid" \
    node -e '
const taskId = process.env.TASK_ID;
const user = process.env.VIEWER_BASIC_AUTH_USER || "";
const pass = process.env.VIEWER_BASIC_AUTH_PASSWORD || "";
const viewerHeaders = {};
if (user || pass) viewerHeaders.authorization = "Basic " + Buffer.from(`${user}:${pass}`).toString("base64");
const base = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabaseHeaders = { apikey: key, authorization: `Bearer ${key}` };
async function main() {
  const taskResponse = await fetch(`http://127.0.0.1:3000/api/tasks/${taskId}`, { headers: viewerHeaders });
  const taskText = await taskResponse.text();
  let task = {};
  try { task = JSON.parse(taskText); } catch {}
  const eventsResponse = await fetch(`${base}/rest/v1/agent_task_events?task_id=eq.${encodeURIComponent(taskId)}&select=event_type,message&order=created_at.asc`, { headers: supabaseHeaders });
  const reportsResponse = await fetch(`${base}/rest/v1/generated_reports?task_id=eq.${encodeURIComponent(taskId)}&select=id,title,report_type`, { headers: supabaseHeaders });
  const events = eventsResponse.ok ? await eventsResponse.json() : [];
  const reports = reportsResponse.ok ? await reportsResponse.json() : [];
  console.log(JSON.stringify({
    httpStatus: taskResponse.status,
    taskStatus: task.status || null,
    error: task.error || null,
    reportId: task.result && task.result.generated_report_id || null,
    eventTypes: Array.isArray(events) ? events.map((event) => event.event_type) : [],
    reportCount: Array.isArray(reports) ? reports.length : 0,
  }));
}
main().catch((error) => { console.error(error.message); process.exit(1); });
' 2>/dev/null)" || fail "failed to query receipt proof status"
  last_summary="$summary"

  task_status="$(printf '%s' "$summary" | node -e 'let s=""; process.stdin.on("data", d => s += d); process.stdin.on("end", () => { const data = JSON.parse(s); process.stdout.write(data.taskStatus || ""); });')"

  if [ "$task_status" = "completed" ]; then
    break
  fi

  if [ "$task_status" = "failed" ]; then
    printf '%s\n' "$summary"
    fail "receipt proof task failed"
  fi

  now_epoch="$(date +%s)"
  elapsed=$((now_epoch - start_epoch))
  if [ "$elapsed" -ge "$TIMEOUT_SECONDS" ]; then
    printf '%s\n' "$summary"
    fail "receipt proof timed out after ${TIMEOUT_SECONDS}s"
  fi

  sleep "$POLL_SECONDS"
done

node -e '
const required = new Set(["claimed", "started", "checkpoint", "completed"]);
const summary = JSON.parse(process.argv[1]);
const eventTypes = new Set(summary.eventTypes || []);
const missing = [...required].filter((type) => !eventTypes.has(type));
if (missing.length || !summary.reportId || summary.reportCount < 1) {
  console.error(JSON.stringify({ missingEvents: missing, reportId: summary.reportId, reportCount: summary.reportCount }));
  process.exit(1);
}
' "$last_summary" || fail "receipt proof completed but persisted records are incomplete"

ok "Task completed"
ok "Events persisted: claimed, started, checkpoint, completed"
ok "Generated receipt report persisted"
info "Task ID: $task_id"
