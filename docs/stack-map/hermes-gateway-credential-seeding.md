# Hermes Gateway Credential Seeding Map

This map documents how the local Docker Compose gateway receives credentials without committing secrets.

## Flow

```text
docker-compose.env
  -> Docker Compose variable expansion
  -> hermes-gateway container environment
  -> gateway-bootstrap.sh
  -> /data/hermes/.env in hermes-home volume
  -> heartbeat and optional task runner
```

## Files

| File | Role | Contains secrets? | Git status |
| --- | --- | ---: | --- |
| `docker-compose.env` | Local Compose source of truth | yes | ignored |
| `docker-compose.env.example` | Template | no | tracked |
| `docker-compose.yml` | Service wiring and variable names | no | tracked |
| `hermes-agent/scripts/gateway-bootstrap.sh` | Seeds selected variables | no | local integration file |
| `/data/hermes/.env` | Runtime env inside Docker volume | yes | outside git |

## Seeded Key Groups

```text
AGENT_TOKEN
ORP_*
OPENROUTER_API_KEY / GOOGLE_API_KEY / GEMINI_API_KEY / OLLAMA_API_KEY
TELEGRAM_BOT_TOKEN / DISCORD_BOT_TOKEN / SLACK_BOT_TOKEN / other bot tokens
```

Only configured, non-empty values are written.

## Runtime Processes

```text
offensive-research-portal-heartbeat.py
  POST /api/agent/heartbeat

offensive-research-portal-task-runner.py
  disabled by default
  when enabled: claim task -> update status -> post events -> post generated receipt report

hermes gateway
  main Hermes messaging/runtime process
```

## Task Runner Safety

`ORP_TASK_POLL_ENABLED=false` by default. If enabled, the current runner supports only `ORP_TASK_EXECUTION_MODE=receipt`. Receipt mode proves API plumbing but does not perform external testing against the task target.

## Safe Checks

Do not print token values. Use presence/status checks instead:

```bash
docker compose --env-file docker-compose.env --profile offensive-research-portal --profile hermes-gateway ps
docker compose --env-file docker-compose.env --profile hermes-gateway logs --tail=80 hermes-gateway
docker exec ai_research-hermes-gateway-1 sh -lc 'test -s /data/hermes/.env && echo hermes env seeded'
```

## Rotation Rule

Update `docker-compose.env`, restart the affected services, and verify heartbeat. If the runtime file must be fully reseeded, remove `/data/hermes/.env` from the `hermes-home` volume and restart the gateway.

## Related Docs

- [Hermes Gateway Credentials](../integrations/hermes-gateway-credentials.md)
- [Hermes Gateway API Integration](../integrations/hermes-gateway-api-integration.md)
- [Hermes Gateway Quick Start](../operations/hermes-gateway-quickstart.md)
