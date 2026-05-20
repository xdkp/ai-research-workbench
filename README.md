# AI Research Workbench

Pentest workbench where one command bootstraps the full stack. **Operator is the decision maker. AI is the research assistant.**

## Quick Start

```bash
docker compose up        # boots portal, Hermes, scanner
./scripts/doctor.sh      # workspace health summary
```

## Docs

| What | Where |
|------|-------|
| Product architecture | `plan.md` |
| Workspace model + agent rules | `CLAUDE.md` |
| Implementation roadmap | `csp-audit/plan.md` |

## Projects

| Project | Role |
|---------|------|
| `csp-audit` | Portal + Supabase — source of truth for security data |
| `hermes-agent` | Agent runtime — offensive pentesting execution |
| `cc-switch` | Central management platform (Tauri/Rust) |
| `Fabric` | AI pattern library — report writing and enrichment |
| `pentest-ai-agents` | Methodology reference — 35 specialist pentest agents |
| `oh-my-claudecode` | Claude Code orchestration — 19 dev agents |
| `uqlm` | Hallucination detection — uncertainty quantification |

## Health

```bash
./scripts/check-paths.sh     # verify filesystem paths
./scripts/check-tools.sh     # check required CLI tools
./scripts/check-repos.sh     # status of all child repos
./scripts/doctor.sh          # full workspace health summary
```
