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
  Recalled 2 memories, wrote 3 memories (ctrl+o to expand)

● Memory saved. Here's what a new session will pick up:

  Where we are:
  - Release A: 9/10 done — only operator triage UI remains
  - CI: Mostly green — csp-audit Preview DAST Gate is the last failing check

  The CI failure: Vercel SSO Protection blocks the preview URL with 401. The
  VERCEL_AUTOMATION_BYPASS_SECRET secret is stale (from old csp-audit project). Fix options:
  1. Get the correct bypass secret from Vercel dashboard → m0bious-projects/report-viewer → Settings →
  Deployment Protection → Protection Bypass for Automation 
  2. Or disable SSO Protection on the project

  Key references saved:
  - memory/reference/vercel-setup.md — all Vercel project IDs, tokens, org config
  - memory/current-work.md — full Release A status, branch state, CI status
  - memory/feedback/ — push to xdkp, verify before push, check CI after push