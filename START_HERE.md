
# AI Research Workbench - Start Here

This folder is the local operating workspace for an AI-assisted security research and reporting system.

The goal is not to merge all upstream projects into one codebase. The goal is to make them work together through one clear local workflow.

## What This Workspace Is For

```text
scope -> approved task -> execution evidence -> structured finding -> operator triage -> final report/export
```

`csp-audit` is the system of record for security scope, tasks, evidence, findings, approvals, and reportable output.

The other projects support that workflow:

| Project | Role |
|---|---|
| `csp-audit` | Security workflow control plane, scanner, DAST, evidence, findings, reports |
| `hermes-agent` | Agent runtime and long-running executor for approved work |
| `Fabric` | Reusable prompt-pattern and analysis library |
| `cc-switch` | Provider/profile switchboard for AI coding CLIs |
| `Ollama` | Local model runtime for optional local inference |
| `oh-my-claudecode` | Claude Code customization/support tooling |
| `.agents` / `.codex` | Local assistant metadata and workspace config |

## First Path On A New Machine

1. Confirm the workspace is on the Linux ext4 dev partition:

```bash
pwd
findmnt /mnt/develop
df -hT /mnt/develop
```

2. Read the new-machine checklist:

```text
docs/onboarding/new-machine-setup.md
```

3. Check required tools:

```bash
./scripts/check-tools.sh
```

4. Check expected paths:

```bash
./scripts/check-paths.sh
```

5. Run the read-only workspace doctor:

```bash
./scripts/doctor.sh
```

6. Check the repository map:

```bash
./scripts/check-repos.sh
```

7. Work from the repo that owns the task:

```text
Security workflow / reports  -> csp-audit
Agent runtime / gateway      -> hermes-agent
Prompt patterns              -> Fabric
Provider/profile switching   -> cc-switch
Local model runtime          -> Ollama
Claude Code customization    -> oh-my-claudecode
```

## What Not To Do First

Do not start by moving upstream source trees.

Do not create a second finding database outside `csp-audit`.

Do not let Fabric, Hermes, or cc-switch become the source of truth for security findings. They can assist and generate material, but approved findings and reportable evidence belong in `csp-audit`.

Do not introduce Kubernetes yet. Use native tools first and Docker Compose later for repeatable services.

## Important Local Notes

- Active workspace: `/mnt/develop/AI_Research`
- Build partition: `/mnt/develop`
- Old NTFS/archive partition, if mounted: `/mnt/new_volume`
- `cc-switch/src-tauri/target` can grow very large. Treat it as disposable Rust build cache.
- Ollama model storage target: `/mnt/develop/ollama-models`.
- The workspace root is a meta-repo and intentionally ignores the child project repositories.
- Root GitHub remote: `https://github.com/xdkp/ai-research-workbench.git`

## Next Docs

- `docs/plans/README.md`
- `docs/stack-map/component-map.md`
- `docs/stack-map/repository-manifest.md`
- `docs/stack-map/command-map.md`
- `docs/stack-map/config-ownership.md`
- `docs/stack-map/env-var-inventory.md`
- `docs/integrations/hermes-with-csp-audit.md`
- `docs/operations/account-recovery.md`
