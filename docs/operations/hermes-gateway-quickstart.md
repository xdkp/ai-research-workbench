# Hermes Gateway Quick Start

This is the shortest local path for running the Docker Compose csp-audit + Hermes gateway slice. It keeps Vercel out of scope.

## What This Starts

```text
csp-report-viewer  -> local csp-audit UI/API at http://localhost:3000
csp-scan-worker    -> local scan polling worker
hermes-gateway     -> Hermes gateway plus csp-audit heartbeat bridge
```

Task claiming is available but disabled by default so the gateway does not consume queued work by accident.

## 1. Create Local Env

```bash
cd /mnt/develop/AI_Research
cp docker-compose.env.example docker-compose.env
nano docker-compose.env
```

Required minimum values:

```text
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
AGENT_TOKEN
one Hermes provider key, such as OPENROUTER_API_KEY or GOOGLE_API_KEY
```

Keep `docker-compose.env` local. It is ignored by git.

## 2. Start csp-audit

```bash
docker compose --env-file docker-compose.env --profile csp-audit up -d
docker compose --env-file docker-compose.env --profile csp-audit ps
```

Expected:

```text
csp-report-viewer   up, healthy
csp-scan-worker     up
```

Open the local UI:

```text
http://localhost:3000
```

## 3. Start Hermes Gateway

```bash
docker compose --env-file docker-compose.env --profile hermes-gateway up -d
docker compose --env-file docker-compose.env --profile hermes-gateway ps
```

Check logs without printing secrets:

```bash
docker compose --env-file docker-compose.env --profile hermes-gateway logs --tail=80 hermes-gateway
```

Expected heartbeat line:

```text
csp-audit heartbeat ok: hermes-gateway
```

## 4. Optional: Enable Task Bridge Receipt Mode

Receipt mode proves task claim, event posting, generated report submission, and status update. It does not perform real testing against the target.

Edit `docker-compose.env`:

```text
CSP_AUDIT_TASK_POLL_ENABLED=true
CSP_AUDIT_TASK_POLL_INTERVAL_SECONDS=60
CSP_AUDIT_TASK_EXECUTION_MODE=receipt
```

Restart the gateway:

```bash
docker compose --env-file docker-compose.env --profile hermes-gateway restart hermes-gateway
```

## 5. Create A Safe Test Task

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

Watch the gateway:

```bash
docker compose --env-file docker-compose.env --profile hermes-gateway logs --tail=100 hermes-gateway
```

Expected result in csp-audit:

```text
task claimed
task events created
generated receipt report created
task marked completed
```

## Stop

```bash
docker compose --env-file docker-compose.env --profile csp-audit --profile hermes-gateway down
```

## Rebuild After Code Changes

```bash
docker compose --env-file docker-compose.env --profile csp-audit --profile hermes-gateway up -d --build csp-report-viewer hermes-gateway
```

## Next

After receipt mode is proven, replace the receipt runner with a scoped Hermes execution adapter that performs approved work and sends evidence-backed candidate findings back to csp-audit.

See: [Hermes Gateway API Integration](../integrations/hermes-gateway-api-integration.md).
