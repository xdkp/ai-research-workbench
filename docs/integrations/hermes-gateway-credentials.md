# Hermes Gateway Credentials

This document explains the credential flow for the local Docker Compose Hermes gateway. Do not paste real secret values into docs, tickets, commits, or chat logs.

## Source Of Truth

```text
docker-compose.env -> Compose container env -> /data/hermes/.env inside hermes-home volume
```

`docker-compose.env` is ignored by git and is the host-side place to rotate local Compose credentials.

## Required Values

| Variable | Required For | Notes |
| --- | --- | --- |
| `AGENT_TOKEN` | csp-audit Agent API | Shared by report viewer and Hermes gateway |
| `SUPABASE_URL` | csp-audit persistent state | Server-side only |
| `SUPABASE_SERVICE_ROLE_KEY` | csp-audit persistent state | Never expose to browser or logs |
| `CSP_AUDIT_BASE_URL` | gateway bridge | Compose internal URL, normally `http://csp-report-viewer:3000` |
| `OPENROUTER_API_KEY` or another provider key | Hermes reasoning | Pick one provider for Hermes |

Optional task bridge values:

| Variable | Default | Notes |
| --- | --- | --- |
| `CSP_AUDIT_TASK_POLL_ENABLED` | `false` | Set `true` only when the gateway should consume tasks |
| `CSP_AUDIT_TASK_POLL_INTERVAL_SECONDS` | `60` | Task claim poll interval |
| `CSP_AUDIT_TASK_EXECUTION_MODE` | `receipt` | Current safe proof mode; performs no target testing |

## Seeding Behavior

On container start, `hermes-agent/scripts/gateway-bootstrap.sh` copies selected environment variables into `/data/hermes/.env`. Existing keys are replaced with the current Compose values; unrelated file contents are preserved.

The bootstrap starts:

```text
csp-audit-heartbeat.py       always, when base URL and token are present
csp-audit-task-runner.py     only when CSP_AUDIT_TASK_POLL_ENABLED=true
hermes gateway               foreground process
```

## Rotate Credentials

1. Edit `docker-compose.env`.
2. Restart affected services.

```bash
docker compose --env-file docker-compose.env --profile csp-audit restart
docker compose --env-file docker-compose.env --profile hermes-gateway restart hermes-gateway
```

For a clean reseed of `/data/hermes/.env`, remove only that file from the named volume and restart the gateway. Do this only when you intentionally want Compose to recreate the runtime env file.

```bash
docker run --rm -v ai_research_hermes-home:/data/hermes alpine rm -f /data/hermes/.env
docker compose --env-file docker-compose.env --profile hermes-gateway restart hermes-gateway
```

## Safe Verification

Use checks that prove presence without printing secret values:

```bash
docker compose --env-file docker-compose.env --profile hermes-gateway logs --tail=80 hermes-gateway
docker compose --env-file docker-compose.env --profile csp-audit --profile hermes-gateway ps
docker compose --env-file docker-compose.env --profile csp-audit --profile hermes-gateway config --quiet
```

Inside-container presence check without values:

```bash
docker exec ai_research-hermes-gateway-1 sh -lc 'test -s /data/hermes/.env && echo hermes env seeded'
```

## API Endpoints Used

The gateway uses these csp-audit endpoints with `Authorization: Bearer <AGENT_TOKEN>`:

```text
POST  /api/agent/heartbeat
POST  /api/agent/tasks/claim
PATCH /api/agent/tasks/[id]
POST  /api/agent/events
POST  /api/agent/reports/generated
```

See [Hermes Gateway API Integration](hermes-gateway-api-integration.md) for the task bridge workflow.
