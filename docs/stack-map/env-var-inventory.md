
# Environment Variable Inventory

This is the workspace-level index. Do not paste real secrets here.

## Minimal Local Agent

| Variable | Owner | Required? | Notes |
|---|---|---:|---|
| Provider API key | Hermes or cc-switch | yes | Depends on selected model/provider |
| `HERMES_HOME` | Hermes | optional | Only if overriding default config path |
| `OLLAMA_HOST` | Ollama/client tools | optional | Only if not using the default local endpoint |
| `OLLAMA_MODELS` | Ollama | recommended if storing models on `/mnt/develop` | Target: `/mnt/develop/ollama-models` |

## Ollama Local Models

| Variable | Owner | Required? | Notes |
|---|---|---:|---|
| `OLLAMA_MODELS` | Ollama service | recommended | Use `/mnt/develop/ollama-models` so large model files stay on the ext4 dev partition |
| `OLLAMA_HOST` | Ollama clients | optional | Use only when the daemon is not on the default local endpoint |

Ollama hosts local model files and inference. It does not own security tasks, evidence, approvals, findings, or reports.

## offensive-research-portal Local-Only

| Variable | Owner | Required? | Notes |
|---|---|---:|---|
| none for root unit tests | offensive-research-portal | no | `pnpm test` should run local tests |
| `REPORT_VIEWER_BASE_URL` | offensive-research-portal worker | only polling | Used by scan worker polling |
| `SCAN_WORKER_TOKEN` | offensive-research-portal worker | only worker API | Shared secret for worker routes |

## offensive-research-portal Supabase / Vercel

| Variable | Owner | Required? | Notes |
|---|---|---:|---|
| `SUPABASE_URL` | offensive-research-portal | yes for hosted DB | Server-side only |
| `SUPABASE_SERVICE_ROLE_KEY` | offensive-research-portal | yes for hosted DB | Never expose to browser |
| `SUPABASE_REQUEST_TIMEOUT_MS` | offensive-research-portal | optional | Server-side Supabase request timeout; default `8000` so agent routes fail cleanly instead of hanging |
| `AGENT_TOKEN` | offensive-research-portal agent routes | yes for agent API | Shared secret for Hermes/agent routes |
| `VIEWER_BASIC_AUTH_USER` | report-viewer | recommended | Protects browser/API viewer |
| `VIEWER_BASIC_AUTH_PASSWORD` | report-viewer | recommended | Must be paired with user |
| `VIEWER_SESSION_SECRET` | report-viewer | optional | Session signing if configured |
| `VERCEL_TOKEN` | Vercel/GitHub Actions | only deploy/preview DAST | Account-specific |
| `VERCEL_ORG_ID` | Vercel/GitHub Actions | only deploy/preview DAST | Account/team-specific |
| `VERCEL_PROJECT_ID` | Vercel/GitHub Actions | only deploy/preview DAST | Project-specific |
| `VERCEL_AUTOMATION_BYPASS_SECRET` | Vercel preview protection | only preview DAST | Do not confuse with project token |
| `REPORT_VIEWER_BASE_URL` | GitHub Actions variable | production DAST/local worker | Set to the new Vercel production URL after first deploy |

## Hermes Gateway Bots

| Variable | Owner | Required? | Notes |
|---|---|---:|---|
| Telegram/Discord/Slack/etc bot tokens | Hermes | only if gateway enabled | Rotate if bot account changes |
| `HERMES_HOME` | Hermes | optional | Overrides the gateway runtime config root if you do not want the default `~/.hermes` |
| `ORP_BASE_URL` | offensive-research-portal | yes for agent heartbeat wiring | Used by Hermes gateway heartbeat bridge to reach `/api/agent/heartbeat` |
| `ORP_AGENT_NAME` | Hermes | optional | Agent identity reported to offensive-research-portal |
| `ORP_AGENT_MODEL` | Hermes | optional | Model string reported to offensive-research-portal |
| `ORP_AGENT_PROFILE` | Hermes | optional | Profile string reported to offensive-research-portal |
| `ORP_TASK_POLL_ENABLED` | Hermes/offensive-research-portal bridge | optional | Default `false`; set `true` only when the gateway should consume approved/not-required tasks |
| `ORP_TASK_POLL_INTERVAL_SECONDS` | Hermes/offensive-research-portal bridge | optional | Poll delay for task claiming loop |
| `ORP_TASK_EXECUTION_MODE` | Hermes/offensive-research-portal bridge | optional | Current supported value is `receipt`; proves API plumbing without target testing |
| `ORP_MODEL_ROUTING_ENABLED` | Hermes/cc-switch bridge | optional | Default `true`; Hermes asks cc-switch for model selection when the local router is reachable |
| `CC_SWITCH_MODEL_ROUTER_URL` | Hermes/cc-switch bridge | optional | Default `http://host.docker.internal:15721/cc-switch/models/route` in Docker Compose |
| `CC_SWITCH_MODEL_ROUTER_APP` | Hermes/cc-switch bridge | optional | cc-switch app/profile namespace, default `gemini` |
| `SYNC_WORKER_ENABLED` | Hermes/offensive-research-portal bridge | optional | Default `false`; enable only after the local sync queue schema exists |
| `HERMES_GATEWAY_INSTALL_BROWSER_TOOLS` | Hermes Docker build/runtime | optional | Default `false`; opt in for Playwright/browser-validation images |
| `HERMES_GATEWAY_INSTALL_UQLM_DEPS` | Hermes Docker build/runtime | optional | Default `false`; opt in for UQLM validation images; may install heavy ML dependencies |

## cc-switch Provider Profiles

| Variable | Owner | Required? | Notes |
|---|---|---:|---|
| `ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_API_KEY` | cc-switch profile | provider-specific | May be written into Claude-compatible config |
| `OPENAI_API_KEY` | cc-switch/Codex profile | provider-specific | May be stored in Codex auth/config |
| `GEMINI_API_KEY` | cc-switch/Gemini profile | provider-specific | Depends on Gemini mode |

## Rule

If a key is needed in more than one place, record:

```text
why it is duplicated
where the primary copy lives
how to rotate it
which services must restart
```
