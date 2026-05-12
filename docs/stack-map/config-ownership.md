
# Config Ownership

The combined workspace should avoid duplicate sources of truth.

| Config Area | Owner | Should Not Own |
|---|---|---|
| Security engagements/scope/tasks/findings/evidence/reports | `csp-audit` | Hermes, Fabric, cc-switch |
| Agent runtime, memory, gateway, skills | `hermes-agent` | csp-audit finding state |
| Prompt patterns and analysis templates | `Fabric` | evidence records, approvals, task queues |
| Provider/profile switching for coding CLIs | `cc-switch` | csp-audit report state, Hermes memory |
| Local model hosting/runtime | `Ollama` | task state, findings, evidence, approvals, provider policy |
| Claude Code customization | `oh-my-claudecode` / Claude config | provider source of truth when cc-switch manages it |
| Codex workspace behavior | `.codex` | security findings and evidence |
| Local agent metadata | `.agents` | account secrets unless explicitly designed |

## Security Workflow Boundary

`csp-audit` is authoritative for:

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

Hermes may execute approved work and draft candidate material. Fabric may help analyze or write. cc-switch may select the provider/model. Ollama may serve local models. Final reportable records stay in `csp-audit`.

## Provider Boundary

Preferred rule:

```text
cc-switch = provider/profile switchboard for coding CLIs
Ollama = local model runtime, not workflow state
Hermes = its own runtime config unless explicitly integrated
csp-audit = only the tokens required for scanner/report-viewer/control-plane
```

If a provider key is duplicated across tools, document why in `env-var-inventory.md`.
