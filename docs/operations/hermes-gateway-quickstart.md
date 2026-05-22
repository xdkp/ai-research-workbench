# Hermes Gateway Quick Start

This is the shortest local path for running the Docker Compose offensive-research-portal + Hermes gateway slice. It keeps Vercel out of scope.

## What This Starts

```text
offensive-research-portal  -> local offensive-research-portal UI/API at http://localhost:3000
csp-scan-worker    -> local scan polling worker
hermes-gateway     -> Hermes gateway plus offensive-research-portal heartbeat bridge
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

## 2. Start offensive-research-portal

```bash
docker compose --env-file docker-compose.env --profile offensive-research-portal up -d
docker compose --env-file docker-compose.env --profile offensive-research-portal ps
```

Expected:

```text
offensive-research-portal   up, healthy
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
offensive-research-portal heartbeat ok: hermes-gateway
```

## 4. Optional: Enable Task Bridge Receipt Mode

Receipt mode proves task claim, event posting, generated report submission, and status update. It does not perform real testing against the target.

Edit `docker-compose.env`:

```text
ORP_TASK_POLL_ENABLED=true
ORP_TASK_POLL_INTERVAL_SECONDS=60
ORP_TASK_EXECUTION_MODE=receipt
```

Restart the gateway:

```bash
docker compose --env-file docker-compose.env --profile hermes-gateway restart hermes-gateway
```

## 5. Prove Receipt Mode

Run the repeatable smoke check:

```bash
./scripts/prove-hermes-receipt-loop.sh
```

The script creates a harmless receipt-mode task, restarts the gateway so it polls immediately, and verifies:

```text
task completed
events persisted: claimed, started, checkpoint, completed
generated receipt report persisted
```

It reads credentials from the running containers and does not print secret values.

## Stop

```bash
docker compose --env-file docker-compose.env --profile offensive-research-portal --profile hermes-gateway down
```

## Rebuild After Code Changes

```bash
docker compose --env-file docker-compose.env --profile offensive-research-portal --profile hermes-gateway up -d --build offensive-research-portal hermes-gateway
```

## Next

After receipt mode is proven, replace the receipt runner with a scoped Hermes execution adapter that performs approved work and sends evidence-backed candidate findings back to offensive-research-portal.

See: [Hermes Gateway API Integration](../integrations/hermes-gateway-api-integration.md).
