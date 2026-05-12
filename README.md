
# AI Research Workbench

This is a local workspace that combines several AI/security tools into one operating environment.

The core workflow is:

```text
scope -> approved task -> execution evidence -> structured finding -> operator triage -> final report/export
```

`csp-audit` is the source of truth for security workflow state. Hermes, Fabric, cc-switch, Ollama, Codex, and Claude Code support that workflow.

Start here:

```text
START_HERE.md
```

## Workspace Layout

```text
AI_Research/
├── START_HERE.md
├── README.md
├── docs/
├── scripts/
├── Fabric/
├── cc-switch/
├── csp-audit/
├── hermes-agent/
└── oh-my-claudecode/
```

## Role Summary

| Component | Purpose |
|---|---|
| `csp-audit` | Security control plane, scanner, findings, evidence, reports |
| `hermes-agent` | Agent runtime, CLI/TUI, gateway, memory, skills, tools |
| `Fabric` | Prompt-pattern library for repeatable analysis and writing workflows |
| `cc-switch` | Provider/profile switching for AI CLI tools |
| `Ollama` | Optional local model runtime for local inference |
| `oh-my-claudecode` | Claude Code customization/support tooling |

## Health Checks

```bash
./scripts/check-paths.sh
./scripts/check-tools.sh
./scripts/doctor.sh
./scripts/check-repos.sh
```

The scripts are read-only. They do not install dependencies, log into accounts, or print secrets.

## Repository Model

This root folder is a meta-repo. It tracks the workbench docs and scripts only.

The project folders keep their own Git histories:

```text
Fabric/
cc-switch/
csp-audit/
hermes-agent/
oh-my-claudecode/
```

See:

```text
docs/stack-map/repository-manifest.md
```

## Planning Archive

Historical workbench planning records are archived here:

```text
docs/plans/README.md
```
