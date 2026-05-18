
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

## csp-audit Local-Only

| Variable | Owner | Required? | Notes |
|---|---|---:|---|
| none for root unit tests | csp-audit | no | `pnpm test` should run local tests |
| `REPORT_VIEWER_BASE_URL` | csp-audit worker | only polling | Used by scan worker polling |
| `SCAN_WORKER_TOKEN` | csp-audit worker | only worker API | Shared secret for worker routes |

## csp-audit Supabase / Vercel

| Variable | Owner | Required? | Notes |
|---|---|---:|---|
| `SUPABASE_URL` | csp-audit | yes for hosted DB | Server-side only |
| `SUPABASE_SERVICE_ROLE_KEY` | csp-audit | yes for hosted DB | Never expose to browser |
| `SUPABASE_REQUEST_TIMEOUT_MS` | csp-audit | optional | Server-side Supabase request timeout; default `8000` so agent routes fail cleanly instead of hanging |
| `AGENT_TOKEN` | csp-audit agent routes | yes for agent API | Shared secret for Hermes/agent routes |
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
| `CSP_AUDIT_BASE_URL` | csp-audit | yes for agent heartbeat wiring | Used by Hermes gateway heartbeat bridge to reach `/api/agent/heartbeat` |
| `CSP_AUDIT_AGENT_NAME` | Hermes | optional | Agent identity reported to csp-audit |
| `CSP_AUDIT_AGENT_MODEL` | Hermes | optional | Model string reported to csp-audit |
| `CSP_AUDIT_AGENT_PROFILE` | Hermes | optional | Profile string reported to csp-audit |
| `CSP_AUDIT_TASK_POLL_ENABLED` | Hermes/csp-audit bridge | optional | Default `false`; set `true` only when the gateway should consume approved/not-required tasks |
| `CSP_AUDIT_TASK_POLL_INTERVAL_SECONDS` | Hermes/csp-audit bridge | optional | Poll delay for task claiming loop |
| `CSP_AUDIT_TASK_EXECUTION_MODE` | Hermes/csp-audit bridge | optional | Current supported value is `receipt`; proves API plumbing without target testing |

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
