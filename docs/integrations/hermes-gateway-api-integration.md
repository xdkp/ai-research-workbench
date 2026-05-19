# Hermes Gateway API Integration with csp-audit

This guide documents the local Docker Compose bridge between `hermes-agent` and `csp-audit`. Receipt mode now proves the control-plane path before adding real execution adapters.

## Ownership Boundary

```text
csp-audit      owns scope, task queue, approvals, events, findings, generated reports
Hermes gateway claims approved work and posts execution records back to csp-audit
Fabric         may provide analysis/reporting patterns later
cc-switch      owns provider/profile switching outside the csp-audit record system
Ollama         is optional local model runtime, not a task or evidence store
```

## Current Wiring

```text
hermes-gateway container
├── gateway-bootstrap.sh
│   ├── seeds selected docker-compose.env values into /data/hermes/.env
│   ├── starts csp-audit-heartbeat.py
│   └── starts csp-audit-task-runner.py only when explicitly enabled
├── csp-audit-heartbeat.py
│   └── POST /api/agent/heartbeat
├── csp-audit-task-runner.py
│   ├── POST /api/agent/tasks/claim
│   ├── PATCH /api/agent/tasks/[id]
│   ├── POST /api/agent/events
│   └── POST /api/agent/reports/generated
└── hermes gateway
    └── main Hermes messaging/runtime process
```

## Status

| Capability | Status | Notes |
| --- | --- | --- |
| Credential seeding | Implemented | `docker-compose.env` is copied into `/data/hermes/.env` for selected runtime keys |
| Heartbeat | Implemented | Runs by default when `CSP_AUDIT_BASE_URL` and `AGENT_TOKEN` exist |
| Task claiming | Implemented, opt-in, proved | Disabled unless `CSP_AUDIT_TASK_POLL_ENABLED=true` |
| Event posting | Implemented, opt-in, proved | Runner posts `started`, `checkpoint`, and `completed` events |
| Result submission | Implemented, opt-in, proved | Runner submits a markdown receipt report |
| Receipt proof | Proved 2026-05-19 | Task `6d409002-89ea-490e-8135-a69302f4410e` completed with four persisted events and one generated report |
| Real security execution | Not proved | Receipt mode performs no target interaction, scanning, or exploitation |

## Required Environment

Set these in `docker-compose.env` before starting Compose. Do not commit that file.

| Variable | Required | Purpose |
| --- | ---: | --- |
| `SUPABASE_URL` | yes for persisted csp-audit state | Report viewer/control plane database |
| `SUPABASE_SERVICE_ROLE_KEY` | yes for persisted csp-audit state | Server-side Supabase access |
| `AGENT_TOKEN` | yes | Shared bearer token for `/api/agent/*` routes |
| `CSP_AUDIT_BASE_URL` | yes for gateway bridge | Internal Compose URL, normally `http://csp-report-viewer:3000` |
| `CSP_AUDIT_AGENT_NAME` | recommended | Agent identity in heartbeat/events |
| `CSP_AUDIT_TASK_POLL_ENABLED` | optional | Must be `true` before the gateway consumes tasks |
| `CSP_AUDIT_TASK_POLL_INTERVAL_SECONDS` | optional | Poll delay, default `60` |
| `CSP_AUDIT_TASK_EXECUTION_MODE` | optional | Current supported value: `receipt` |

## Safety Model

The task runner is disabled by default. When enabled, the only supported execution mode is `receipt`. Receipt mode proves this API path:

```text
claim task -> mark running -> post events -> create generated report -> mark completed
```

Receipt mode explicitly does not scan, browse, attack, fuzz, exploit, authenticate to, or otherwise interact with the target. The generated report says that clearly so it cannot be mistaken for evidence from real testing.

## Enable The Local Bridge

Edit `docker-compose.env`:

```bash
CSP_AUDIT_TASK_POLL_ENABLED=true
CSP_AUDIT_TASK_POLL_INTERVAL_SECONDS=60
CSP_AUDIT_TASK_EXECUTION_MODE=receipt
```

Restart the gateway after changing it:

```bash
docker compose --env-file docker-compose.env --profile hermes-gateway restart hermes-gateway
```

If the report-viewer code changed, rebuild the affected services first:

```bash
docker compose --env-file docker-compose.env --profile csp-audit --profile hermes-gateway up -d --build csp-report-viewer hermes-gateway
```

## Create A Local Test Task

Use a harmless public documentation target for the bridge proof. Do not use this receipt runner for real testing evidence.

```bash
curl -X POST http://localhost:3000/api/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Local Hermes gateway bridge proof",
    "instructions": "Prove the local gateway can claim a task, post events, submit a generated report, and update task status. Do not perform external testing.",
    "target_url": "https://example.com",
    "target_type": "webapp",
    "risk_level": "low",
    "allowed_actions": "claim,event,report,status",
    "requires_approval": false
  }'
```

The task will be claimable because `requires_approval=false` creates `approval_status=not_required`.

## Verify

```bash
docker compose --env-file docker-compose.env --profile hermes-gateway logs --tail=100 hermes-gateway
```

Expected runner states:

```text
csp-audit task runner: no eligible task
csp-audit task claimed: <task-id>
```

Then check the report viewer UI at `http://localhost:3000` for:

```text
agent heartbeat
task status completed
task events
generated receipt report
```

## Troubleshooting

### Runner stays disabled

Check that `docker-compose.env` contains:

```bash
CSP_AUDIT_TASK_POLL_ENABLED=true
```

Then restart the `hermes-gateway` service.

### Claim returns unauthorized

The gateway and report viewer do not share the same `AGENT_TOKEN`. Rotate/update the token in `docker-compose.env`, then restart both csp-audit and hermes-gateway profiles. Do not print tokens in logs or docs.

### Claim returns agent not found

The gateway must heartbeat before claiming. Wait for one heartbeat interval or restart the gateway and inspect logs.


### Heartbeat returns 500 with Supabase timeout

The gateway can reach `csp-report-viewer`, but the report viewer cannot reach Supabase quickly enough. Verify Supabase project/network access and `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` in `docker-compose.env`. The server-side timeout is controlled by `SUPABASE_REQUEST_TIMEOUT_MS` and defaults to `8000`.

### Task is not claimed

Only queued tasks with `approval_status` of `not_required` or `approved` can be claimed. Pending/rejected approval tasks are intentionally skipped.

## Next Implementation Step

Keep receipt mode as the safe default and add a scoped Hermes execution adapter that:

1. Reads the csp-audit task instructions and allowed actions.
2. Loads approved Fabric patterns if needed.
3. Executes only the approved workflow.
4. Posts evidence and candidate findings back to csp-audit.
5. Leaves final finding confirmation and report inclusion to the operator.

## References

- [Hermes Gateway Credentials](hermes-gateway-credentials.md)
- [Hermes with csp-audit](hermes-with-csp-audit.md)
- [Docker Compose Local Operations](../operations/docker-compose-local.md)
- [Gateway Quick Start](../operations/hermes-gateway-quickstart.md)
- [Gateway Bootstrap Script](../../hermes-agent/scripts/gateway-bootstrap.sh)
- [Heartbeat Script](../../hermes-agent/scripts/csp-audit-heartbeat.py)
- [Task Runner Script](../../hermes-agent/scripts/csp-audit-task-runner.py)
