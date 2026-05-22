
# Config Ownership

The combined workspace should avoid duplicate sources of truth.

| Config Area | Owner | Should Not Own |
|---|---|---|
| Security engagements/scope/tasks/findings/evidence/reports | `offensive-research-portal` | Hermes, Fabric, cc-switch |
| Agent runtime, memory, gateway, skills | `hermes-agent` | offensive-research-portal finding state |
| Prompt patterns and analysis templates | `Fabric` | evidence records, approvals, task queues |
| Provider/profile switching for coding CLIs | `cc-switch` | offensive-research-portal report state, Hermes memory |
| Local model hosting/runtime | `Ollama` | task state, findings, evidence, approvals, provider policy |
| Claude Code customization | `oh-my-claudecode` / Claude config | provider source of truth when cc-switch manages it |
| Codex workspace behavior | `.codex` | security findings and evidence |
| Local agent metadata | `.agents` | account secrets unless explicitly designed |

## Security Workflow Boundary

`offensive-research-portal` is authoritative for:

```text
scope
tasks
approval status
task events
evidence
structured findings
triage status
generated reports
submissions
exports
```

Hermes may execute approved work and draft candidate material. Fabric may help analyze or write. cc-switch may select the provider/model. Ollama may serve local models. Final reportable records stay in `offensive-research-portal`.

Hermes-owned runtime config may carry offensive-research-portal connection settings and heartbeat credentials, but the agent task queue, evidence, and finding records still belong to `offensive-research-portal`.

## Provider Boundary

Preferred rule:

```text
cc-switch = provider/profile switchboard for coding CLIs
Ollama = local model runtime, not workflow state
Hermes = its own runtime config unless explicitly integrated
offensive-research-portal = only the tokens required for scanner/report-viewer/control-plane
```

If a provider key is duplicated across tools, document why in `env-var-inventory.md`.

## Docker Compose Credential Boundary

For the local Compose slice, `docker-compose.env` is the host-side source for container runtime credentials. The Hermes gateway bootstrap copies only selected keys into `/data/hermes/.env` inside the `hermes-home` volume.

`ORP_TASK_POLL_ENABLED` is intentionally disabled by default. Turning it on allows Hermes gateway to consume offensive-research-portal tasks, so use it only when you are testing or running the approved local bridge.
