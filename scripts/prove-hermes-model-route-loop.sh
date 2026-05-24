#!/usr/bin/env bash
set -euo pipefail

ROOT="${AI_RESEARCH_ROOT:-/mnt/develop/AI_Research}"
ENV_FILE="${DOCKER_COMPOSE_ENV_FILE:-$ROOT/docker-compose.env}"
TIMEOUT_SECONDS="${HERMES_MODEL_ROUTE_PROOF_TIMEOUT_SECONDS:-120}"
POLL_SECONDS="${HERMES_MODEL_ROUTE_PROOF_POLL_SECONDS:-3}"
TARGET_URL="${HERMES_MODEL_ROUTE_PROOF_TARGET_URL:-https://example.com}"

ok() { printf 'PASS  %s
' "$1"; }
warn() { printf 'WARN  %s
' "$1"; }
fail() { printf 'FAIL  %s
' "$1"; exit 1; }
info() { printf 'INFO  %s
' "$1"; }

compose() {
  docker compose -f "$ROOT/docker-compose.yml" --env-file "$ENV_FILE" "$@"
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

printf 'Hermes model-routing proof
'
printf 'Root: %s
' "$ROOT"
printf 'Env: %s

' "$ENV_FILE"

viewer_cid="$(compose ps -q offensive-research-portal 2>/dev/null || true)"
gateway_cid="$(compose ps -q hermes-gateway 2>/dev/null || true)"

if [ -z "$viewer_cid" ]; then
  fail "offensive-research-portal is not running; start/check with docker compose -f $ROOT/docker-compose.yml --env-file $ENV_FILE --profile offensive-research-portal --profile hermes-gateway up -d"
fi

if [ -z "$gateway_cid" ]; then
  fail "hermes-gateway is not running; start/check with docker compose -f $ROOT/docker-compose.yml --env-file $ENV_FILE --profile hermes-gateway up -d hermes-gateway"
fi

poll_enabled="$(docker exec "$gateway_cid" sh -lc 'printf %s "${ORP_TASK_POLL_ENABLED:-false}"' 2>/dev/null || true)"
mode="$(docker exec "$gateway_cid" sh -lc 'printf %s "${ORP_TASK_EXECUTION_MODE:-receipt}"' 2>/dev/null || true)"
router_url_present="$(docker exec "$gateway_cid" sh -lc 'test -n "${CC_SWITCH_MODEL_ROUTER_URL:-}" && echo yes || echo no' 2>/dev/null || true)"
model_routing_enabled="$(docker exec "$gateway_cid" sh -lc 'printf %s "${ORP_MODEL_ROUTING_ENABLED:-true}"' 2>/dev/null || true)"

if [ "$poll_enabled" != "true" ]; then
  fail "ORP_TASK_POLL_ENABLED is not true in hermes-gateway"
fi

if [ "$mode" != "receipt" ]; then
  fail "ORP_TASK_EXECUTION_MODE is '$mode', expected 'receipt' for this safe proof"
fi

if [ "$model_routing_enabled" = "false" ] || [ "$model_routing_enabled" = "0" ]; then
  fail "ORP_MODEL_ROUTING_ENABLED disables routing in hermes-gateway"
fi

if [ "$router_url_present" != "yes" ]; then
  fail "CC_SWITCH_MODEL_ROUTER_URL is missing in hermes-gateway"
fi

router_reachable="$(docker exec "$gateway_cid" sh -lc 'router="${CC_SWITCH_MODEL_ROUTER_URL%/cc-switch/models/route}"; curl -fsS --max-time 3 "$router/health" >/dev/null && echo yes || echo no' 2>/dev/null || true)"
if [ "$router_reachable" != "yes" ]; then
  fail "cc-switch model router is not reachable from hermes-gateway at CC_SWITCH_MODEL_ROUTER_URL"
fi

ok "Hermes gateway is configured for receipt-mode task polling with model routing enabled"

create_output="$(docker exec   -e PROOF_TARGET_URL="$TARGET_URL"   "$viewer_cid"   node -e '
const user = process.env.VIEWER_BASIC_AUTH_USER || "";
const pass = process.env.VIEWER_BASIC_AUTH_PASSWORD || "";
const headers = { "content-type": "application/json" };
if (user || pass) headers.authorization = "Basic " + Buffer.from(`${user}:${pass}`).toString("base64");
const proofId = new Date().toISOString();
const body = {
  title: `Local Hermes model route proof ${proofId}`,
  instructions: "Prove Hermes can ask cc-switch for a model decision, log that decision to Portal, and complete receipt-mode task handling. Do not perform external testing.",
  target_url: process.env.PROOF_TARGET_URL || "https://example.com",
  target_type: "passive_recon",
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
' 2>/dev/null)" || fail "failed to create model route proof task"

task_id="$(printf '%s' "$create_output" | node -e 'let s=""; process.stdin.on("data", d => s += d); process.stdin.on("end", () => { const data = JSON.parse(s); process.stdout.write(data.id || ""); });')"

if [ -z "$task_id" ]; then
  fail "created task did not return an id"
fi

ok "Created model route proof task $task_id"
info "Restarting hermes-gateway so the runner polls immediately"
compose restart hermes-gateway >/dev/null

start_epoch="$(date +%s)"
last_summary=""

while true; do
  summary="$(docker exec     -e TASK_ID="$task_id"     "$viewer_cid"     node -e '
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
  const eventsResponse = await fetch(`${base}/rest/v1/agent_task_events?task_id=eq.${encodeURIComponent(taskId)}&select=event_type,message,metadata&order=created_at.asc`, { headers: supabaseHeaders });
  const selectionsResponse = await fetch(`${base}/rest/v1/model_selections?task_id=eq.${encodeURIComponent(taskId)}&select=id,selected_model,metadata&order=created_at.desc`, { headers: supabaseHeaders });
  const routesResponse = await fetch(`${base}/rest/v1/model_routing_results?task_id=eq.${encodeURIComponent(taskId)}&select=id,routed_model,reason&order=created_at.desc`, { headers: supabaseHeaders });
  const events = eventsResponse.ok ? await eventsResponse.json() : [];
  const selections = selectionsResponse.ok ? await selectionsResponse.json() : [];
  const routes = routesResponse.ok ? await routesResponse.json() : [];
  console.log(JSON.stringify({
    httpStatus: taskResponse.status,
    taskStatus: task.status || null,
    error: task.error || null,
    eventTypes: Array.isArray(events) ? events.map((event) => event.event_type) : [],
    modelSelectedEvents: Array.isArray(events) ? events.filter((event) => event.event_type === "model_selected").length : 0,
    selectionCount: Array.isArray(selections) ? selections.length : 0,
    routeCount: Array.isArray(routes) ? routes.length : 0,
    selectedModel: Array.isArray(selections) && selections[0] ? selections[0].selected_model : null,
    routedModel: Array.isArray(routes) && routes[0] ? routes[0].routed_model : null,
  }));
}
main().catch((error) => { console.error(error.message); process.exit(1); });
' 2>/dev/null)" || fail "failed to query model route proof status"
  last_summary="$summary"

  task_status="$(printf '%s' "$summary" | node -e 'let s=""; process.stdin.on("data", d => s += d); process.stdin.on("end", () => { const data = JSON.parse(s); process.stdout.write(data.taskStatus || ""); });')"

  if [ "$task_status" = "completed" ]; then
    break
  fi

  if [ "$task_status" = "failed" ]; then
    printf '%s
' "$summary"
    fail "model route proof task failed"
  fi

  now_epoch="$(date +%s)"
  elapsed=$((now_epoch - start_epoch))
  if [ "$elapsed" -ge "$TIMEOUT_SECONDS" ]; then
    printf '%s
' "$summary"
    fail "model route proof timed out after ${TIMEOUT_SECONDS}s"
  fi

  sleep "$POLL_SECONDS"
done

node -e '
const summary = JSON.parse(process.argv[1]);
const missing = [];
if ((summary.modelSelectedEvents || 0) < 1) missing.push("model_selected event");
if ((summary.selectionCount || 0) < 1) missing.push("model_selections row");
if ((summary.routeCount || 0) < 1) missing.push("model_routing_results row");
if (!summary.selectedModel || !summary.routedModel) missing.push("selected/routed model value");
if (missing.length) {
  console.error(JSON.stringify({ missing, summary }));
  process.exit(1);
}
' "$last_summary" || fail "model route proof completed but persisted records are incomplete"

ok "Task completed"
ok "Model-selected event persisted"
ok "Model selection persisted"
ok "Model routing audit persisted"
info "Task ID: $task_id"
