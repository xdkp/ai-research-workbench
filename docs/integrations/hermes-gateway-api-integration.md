# Hermes Gateway API Integration with offensive-research-portal

This guide documents the local Docker Compose bridge between `hermes-agent` and `offensive-research-portal`. Receipt mode now proves the control-plane path before adding real execution adapters.

## Ownership Boundary

```text
offensive-research-portal      owns scope, task queue, approvals, events, findings, generated reports
Hermes gateway claims approved work and posts execution records back to offensive-research-portal
Fabric         may provide analysis/reporting patterns later
cc-switch      owns provider/profile switching outside the offensive-research-portal record system
Ollama         is optional local model runtime, not a task or evidence store
```

## Current Wiring

```text
hermes-gateway container
├── gateway-bootstrap.sh
│   ├── seeds selected docker-compose.env values into /data/hermes/.env
│   ├── starts offensive-research-portal-heartbeat.py
│   └── starts offensive-research-portal-task-runner.py only when explicitly enabled
├── offensive-research-portal-heartbeat.py
│   └── POST /api/agent/heartbeat
├── offensive-research-portal-task-runner.py
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
| Heartbeat | Implemented | Runs by default when `ORP_BASE_URL` and `AGENT_TOKEN` exist |
| Task claiming | Implemented, opt-in, proved | Disabled unless `ORP_TASK_POLL_ENABLED=true` |
| Event posting | Implemented, opt-in, proved | Runner posts `started`, `checkpoint`, and `completed` events |
| Result submission | Implemented, opt-in, proved | Runner submits a markdown receipt report |
| Receipt proof | Proved 2026-05-23 | Task `5261ad04-6014-4453-8ff2-d8c736ffeca4` completed with four persisted events and a generated receipt report |
| Model-route proof | Proved 2026-05-24 | Headless cc-switch router was reachable from `hermes-gateway`; Hermes logged the selected model through Portal and Supabase persisted `model_selections` plus `model_routing_results` rows |
| Real security execution | Not proved | Receipt mode performs no target interaction, scanning, or exploitation |

## Required Environment

Set these in `docker-compose.env` before starting Compose. Do not commit that file.

| Variable | Required | Purpose |
| --- | ---: | --- |
| `SUPABASE_URL` | yes for persisted offensive-research-portal state | Report viewer/control plane database |
| `SUPABASE_SERVICE_ROLE_KEY` | yes for persisted offensive-research-portal state | Server-side Supabase access |
| `AGENT_TOKEN` | yes | Shared bearer token for `/api/agent/*` routes |
| `ORP_BASE_URL` | yes for gateway bridge | Internal Compose URL, normally `http://offensive-research-portal:3000` |
| `ORP_AGENT_NAME` | recommended | Agent identity in heartbeat/events |
| `ORP_TASK_POLL_ENABLED` | optional | Must be `true` before the gateway consumes tasks |
| `ORP_TASK_POLL_INTERVAL_SECONDS` | optional | Poll delay, default `60` |
| `ORP_TASK_EXECUTION_MODE` | optional | Current supported value: `receipt` |
| `ORP_MODEL_ROUTING_ENABLED` | optional | Default `true`; routes model selection through cc-switch before execution when the router is running |
| `CC_SWITCH_MODEL_ROUTER_URL` | optional | Local cc-switch route endpoint reachable from the container |
| `CC_SWITCH_MODEL_ROUTER_APP` | optional | cc-switch app/profile namespace for provider lookup |
| `SYNC_WORKER_ENABLED` | optional | Default `false`; enable only after local sync queue schema is initialized |
| `HERMES_GATEWAY_INSTALL_BROWSER_TOOLS` | optional build/runtime flag | Default `false`; enable only for browser-validation images |
| `HERMES_GATEWAY_INSTALL_UQLM_DEPS` | optional build/runtime flag | Default `false`; enable only for UQLM validation images; may install heavy ML dependencies |

## Safety Model

The task runner is disabled by default. When enabled, the only supported execution mode is `receipt`. Receipt mode proves this API path:

```text
claim task -> mark running -> post events -> create generated report -> mark completed
```

Receipt mode explicitly does not scan, browse, attack, fuzz, exploit, authenticate to, or otherwise interact with the target. The generated report says that clearly so it cannot be mistaken for evidence from real testing.

## Enable The Local Bridge

Edit `docker-compose.env`:

```bash
ORP_TASK_POLL_ENABLED=true
ORP_TASK_POLL_INTERVAL_SECONDS=60
ORP_TASK_EXECUTION_MODE=receipt
```

Restart the gateway after changing it:

```bash
docker compose --env-file docker-compose.env --profile hermes-gateway restart hermes-gateway
```

If the report-viewer code changed, rebuild the affected services first:

```bash
docker compose --env-file docker-compose.env --profile offensive-research-portal --profile hermes-gateway up -d --build offensive-research-portal hermes-gateway
```

## Run The Receipt Smoke Check

Use a harmless public documentation target for the bridge proof. Do not use this receipt runner for real testing evidence.

```bash
./scripts/prove-hermes-receipt-loop.sh
```

Run the model-route proof after the cc-switch GUI proxy or headless model router is listening on port `15721`:

```bash
./scripts/prove-hermes-model-route-loop.sh
```

The scripts create a claimable task with `requires_approval=false`, restarts `hermes-gateway` so it polls immediately, and verifies task status, events, and generated report persistence.

## Verify

```bash
docker compose --env-file docker-compose.env --profile hermes-gateway logs --tail=100 hermes-gateway
```

Expected runner states:

```text
offensive-research-portal task runner: no eligible task
offensive-research-portal task claimed: <task-id>
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
ORP_TASK_POLL_ENABLED=true
```

Then restart the `hermes-gateway` service.

### Claim returns unauthorized

The gateway and report viewer do not share the same `AGENT_TOKEN`. Rotate/update the token in `docker-compose.env`, then restart both offensive-research-portal and hermes-gateway profiles. Do not print tokens in logs or docs.

### Claim returns agent not found

The gateway must heartbeat before claiming. Wait for one heartbeat interval or restart the gateway and inspect logs.


### Heartbeat returns 500 with Supabase timeout

The gateway can reach `offensive-research-portal`, but the report viewer cannot reach Supabase quickly enough. Verify Supabase project/network access and `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` in `docker-compose.env`. The server-side timeout is controlled by `SUPABASE_REQUEST_TIMEOUT_MS` and defaults to `8000`.

### Task is not claimed

Only queued tasks with `approval_status` of `not_required` or `approved` can be claimed. Pending/rejected approval tasks are intentionally skipped.

## Next Implementation Step

Keep receipt mode as the safe default and add a scoped Hermes execution adapter that:

1. Reads the offensive-research-portal task instructions and allowed actions.
2. Loads approved Fabric patterns if needed.
3. Executes only the approved workflow.
4. Posts evidence and candidate findings back to offensive-research-portal.
5. Leaves final finding confirmation and report inclusion to the operator.

## References

- [Hermes Gateway Credentials](hermes-gateway-credentials.md)
- [Hermes with offensive-research-portal](hermes-with-offensive-research-portal.md)
- [Docker Compose Local Operations](../operations/docker-compose-local.md)
- [Gateway Quick Start](../operations/hermes-gateway-quickstart.md)
- [Gateway Bootstrap Script](../../hermes-agent/scripts/gateway-bootstrap.sh)
- [Heartbeat Script](../../hermes-agent/scripts/offensive-research-portal-heartbeat.py)
- [Task Runner Script](../../hermes-agent/scripts/offensive-research-portal-task-runner.py)
