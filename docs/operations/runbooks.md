# Operational Runbooks

## Stale Agent

**TRIGGER:** No heartbeat from Hermes within 90 seconds

**STEPS:**
1. Portal shows agent status: STALE
2. Check: is the Docker container running? → `docker ps | grep hermes`
3. If stopped → `docker compose restart hermes-gateway`
4. If running but stale → check logs: `docker compose logs hermes-gateway --tail 50`
5. Requeue safe (passive) tasks only
6. NEVER auto-requeue destructive/approved tasks
7. If agent cannot recover → alert operator: "Hermes is down, X tasks paused"
8. Log incident to `audit_log`

## Blocked Approval Queue

**TRIGGER:** > 20 items in quarantine queue OR oldest item > 24h

**STEPS:**
1. Alert operator via portal notification + external channels
2. Show queue summary: X high, Y critical, oldest Z hours ago
3. Operator reviews and bulk-approves/rejects if appropriate
4. If operator unavailable for > 48h:
   - All quarantined tasks remain paused (never auto-approve)
   - Engagement marked as "awaiting operator"
5. Log queue state to `audit_log`

## Model Outage

**TRIGGER:** CircuitBreaker opens on primary model OR all models unavailable

**STEPS:**
1. cc-switch delegates to next model in pool → alert operator
2. If all models down → pause all AI-dependent tasks
3. Alert: "No models available — X tasks paused"
4. Operator checks: model quota, API key validity, Ollama daemon
5. After recovery → manually resume paused tasks
6. Log outage duration and affected tasks to `audit_log`

## Emergency Secret Rotation

**TRIGGER:** Suspected key compromise or account breach

**STEPS:**
1. Immediately revoke: delete key from Supabase `system_config`
2. Generate new key in provider dashboard
3. Update: `docker-compose.env` (local) AND/OR Vercel env (production)
4. Restart affected containers: `docker compose restart`
5. Verify: all services healthy, heartbeat resumed
6. Log rotation event with timestamp + operator to `audit_log`
7. Review: check `audit_log` for unauthorized actions during exposure window
