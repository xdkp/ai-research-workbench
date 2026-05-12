
# AI Research Workbench

This is a local workspace that combines several AI/security tools into one operating environment.

The core workflow is:

```text
scope -> approved task -> execution evidence -> structured finding -> operator triage -> final report/export
```

`csp-audit` is the source of truth for security workflow state. Hermes, Fabric, cc-switch, Codex, and Claude Code support that workflow.

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
| `oh-my-claudecode` | Claude Code customization/support tooling |

## Health Checks

```bash
./scripts/check-paths.sh
./scripts/check-tools.sh
./scripts/doctor.sh
```

The scripts are read-only. They do not install dependencies, log into accounts, or print secrets.
