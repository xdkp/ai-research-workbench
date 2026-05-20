# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Model

This is a **meta-repo** at `/mnt/develop/AI_Research`. The root tracks only workspace-level docs, scripts, and onboarding — not child project source code. Each child project keeps its own Git history and remote:

| Project | Role | Primary Remote |
|---------|------|----------------|
| `csp-audit` | Security workflow system of record (Next.js + Supabase) | `github.com/xdkp/csp-audit.git` |
| `hermes-agent` | Agent runtime, CLI/TUI, gateway, skills (Python) | `github.com/NousResearch/hermes-agent.git` |
| `Fabric` | Prompt-pattern library (Go, Markdown) | `github.com/danielmiessler/Fabric.git` |
| `cc-switch` | Provider/profile switching for AI CLI tools (Tauri/Rust) | `github.com/xdkp/cc-switch-custom.git` |
| `oh-my-claudecode` | Claude Code customization/support tooling | `github.com/Yeachan-Heo/oh-my-claudecode.git` |
| `pentest-ai-agents` | Methodology/prompt reference (read-only, do not vendor) | `github.com/0xSteph/pentest-ai-agents` |
| `uqlm` | Uncertainty quantification for hallucination detection (Python) | `github.com/cvs-health/uqlm` |

Child repos are in `.gitignore`. Do not force them into the root repo.

## System of Record

`csp-audit` is the single source of truth for security workflow data. The pipeline is:

```
scope -> approved task -> execution evidence -> structured finding -> operator triage -> final report/export
```

**Hard rules:**
- Do not create a second findings database outside `csp-audit`.
- Do not let Fabric, Hermes, or cc-switch become the source of truth for security findings.
- `SUPABASE_SERVICE_ROLE_KEY` must never appear in browser/client code. All Supabase access goes through server-side Next.js API routes.
- RLS deny-all on all Supabase tables; only `service_role` bypasses.

## Common Commands

### Workspace health (read-only, run from root)
```bash
./scripts/doctor.sh          # Full workspace health summary
./scripts/check-paths.sh     # Verify expected filesystem paths
./scripts/check-tools.sh     # Check required CLI tools
./scripts/check-repos.sh     # Status of all child repos
```

### csp-audit (run from `csp-audit/`)
```bash
pnpm test                                              # Root scanner + mapping + DAST gate tests
pnpm --prefix report-viewer lint                       # ESLint
pnpm --prefix report-viewer exec vitest run             # Viewer unit tests
pnpm --prefix report-viewer exec tsc --noEmit           # TypeScript check
pnpm --prefix report-viewer build                       # Next.js production build
pnpm scan:poll                                          # Start local scan worker (needs env vars)
pnpm ops:validate                                       # Read-only setup validation
```

### hermes-agent (run from any directory)
```bash
hermes doctor      # Hermes health check
hermes             # Start CLI/TUI
hermes gateway     # Start messaging gateway
```

### Docker Compose (from root)
```bash
docker compose --env-file docker-compose.env --profile csp-audit --profile hermes-gateway up
```

### Other tools
```bash
fabric --help       # Fabric CLI (prompt patterns)
ollama list         # Check if Ollama daemon is reachable
```

## Architecture

### Portal + Supabase data layer
- **Portal** (`csp-audit/report-viewer`): Next.js 15 app on Vercel. Reads from Supabase, renders dashboards and triage UI.
- **Database**: Supabase cloud PostgreSQL. Schema in `csp-audit/supabase/schema.sql` (9+ tables: scans, engagements, findings, agent_tasks, agent_instances, agent_task_events, generated_reports, submissions, submission_duplicates, plus workflow_templates, workflow_plans, model_configs, audit_log, approval_policies, system_config).
- **Local worker** (`csp-audit/csp-playwright-audit.js`): Playwright BFS scanner that polls the portal API for queued scans, executes them, and uploads results. Authenticates with `SCAN_WORKER_TOKEN`.

### Agent bridge
- **Hermes gateway** (`hermes-agent/gateway/`): Claims tasks from csp-audit agent API (`POST /api/agent/tasks/claim`), executes them, posts events and generated reports. Uses `AGENT_TOKEN` for auth.
- **Heartbeat protocol**: Hermes posts to `POST /api/agent/heartbeat` with agent state (idle/busy/paused/waiting_approval). No heartbeat within 60s → agent marked stale.
- **Task execution modes**: `receipt` (safe default, writes receipt report), `analysis` (in progress, enrichment pipeline).

### Operator Authority Policy (non-negotiable)
- Hermes may propose HIGH/CRITICAL actions but requires explicit operator approval before execution.
- Approval is action-level: a Medium finding with a destructive action still requires approval.
- Default-deny if policy evaluation fails. Out-of-scope targets are hard-blocked.
- All approval/rejection decisions are immutable, timestamped, and audited in `audit_log`.

### Local-first deployment
- Primary workflow: `docker compose up` bootstraps local runtime (cc-switch, Fabric, Hermes, scanners, local models).
- Portal can be optionally hosted (Vercel) for read-only reports and operator console.
- Execution components (model runtimes, PoC validation, Fabric patterns, Hermes agents) remain under operator control on local infrastructure.

## Key Files

| File | Purpose |
|------|---------|
| `plan.md` | Product architecture, team design, and safety foundation |
| `csp-audit/plan.md` | Numbered Phase 0-12 implementation roadmap |
| `docker-compose.yml` | Local Docker Compose entry point |
| `docker-compose.env.example` | Template for local secrets (committed, placeholder values) |
| `docs/stack-map/` | Component map, repository manifest, command map, env var inventory, config ownership |
| `docs/integrations/` | Integration contracts between components |
| `docs/operations/current-workspace-status.md` | Live status snapshot of entire workspace |
| `docs/onboarding/new-machine-setup.md` | New-machine checklist |
| `csp-audit/docs/agent-task-contract.md` | Agent API contract |
| `csp-audit/docs/openapi.yaml` | OpenAPI 3.0 spec for Agent API |

## Secret Management

- Local dev: `docker-compose.env` (gitignored). Template: `docker-compose.env.example` (committed).
- Production: Vercel env vars + GitHub Actions secrets.
- Never in code: API keys, tokens, passwords.
- Never expose `SUPABASE_SERVICE_ROLE_KEY` with `NEXT_PUBLIC_` prefix.
- Agent token: shared secret between Hermes and csp-audit API (`AGENT_TOKEN`).
- Emergency rotation: `docs/operations/account-recovery.md`.

## Handling Rules for Child Repos

- **csp-audit**: Active development. Do not reset or discard changes. Branch: `develop`.
- **hermes-agent**: Upstream clone. Local Docker gateway files (`Dockerfile.gateway`, `gateway-bootstrap.sh`, `csp-audit-heartbeat.py`, `csp-audit-task-runner.py`) are workbench integration work — do not push upstream casually.
- **Fabric**: Keep clean unless opening an upstream contribution branch.
- **cc-switch**: Clean repo. Has large Rust build cache (`src-tauri/target`, ~37GB) — clean only when storage pressure requires it.
- **oh-my-claudecode**: Reference/config repo.
- **pentest-ai-agents**: Reference-only for methodology extraction. Do not vendor contents or push changes casually.
- **uqlm**: Upstream clone (Apache 2.0). Used by Hermes for enrichment verification. Install via pip into Hermes container. Do not push changes upstream casually.

## CI/CD (csp-audit)

- `develop` branch: runs tests, lint, build, preview DAST gate.
- `main` branch: runs tests, lint, build, production deploy to Vercel, production DAST evidence workflow with HIGH-severity gate.
- Deploy controller: GitHub Actions (`vercel deploy --prebuilt --prod`). Vercel Git auto-deploy is intentionally disconnected.

## Agent Development Rules

These rules apply to Claude Code when working on any project in this workspace. They ensure every change is tested, verified, and safe before merge.

### Branch and commit rules

1. **Never push directly to `main` or `develop`.** Always work in a feature branch.
2. **Create a new commit for each completed feature or fix.** Do not amend published commits.
3. **Never skip hooks** (`--no-verify`, `--no-gpg-sign`) unless explicitly instructed.
4. **Write conventional commit messages.** Subject under 70 characters, body explaining WHY.

### Pre-PR verification — run before opening a pull request

For every change, run the project's verification commands locally and confirm they pass before opening a PR:

**csp-audit (from `csp-audit/`):**
```bash
pnpm test                                              # scanner + mapping + DAST gate
pnpm --prefix report-viewer lint                       # ESLint
pnpm --prefix report-viewer exec vitest run             # viewer tests
pnpm --prefix report-viewer exec tsc --noEmit           # TypeScript
pnpm --prefix report-viewer build                       # production build
```

**hermes-agent (Python):**
```bash
python3 -m pytest tests/ -x -q                          # Hermes tests
python3 -c "import ast; ast.parse(open('scripts/SCRIPT.py').read())"  # syntax check
```

### Testing rules

5. **Before changing implementation code, add or update tests** that prove the behavior.
6. **Run the same commands as CI before opening a PR** — if CI would catch it, catch it locally first.
7. **Do not claim success unless all required checks pass.** If tests fail, fix them. If build fails, fix it.
8. **For new features, test end-to-end** — not just unit tests. Verify the feature works in the real app.
9. **Test against real APIs where possible.** Mock-only tests can miss real-world response shape changes.

### Security boundaries

10. **Do not modify `.github/workflows/`, `CODEOWNERS`, or CI/CD files** unless the change is explicitly requested and scoped.
11. **Do not modify `supabase/schema.sql` RLS policies** to grant browser/client access. All access goes through server-side API routes with `service_role`.
12. **Never expose `SUPABASE_SERVICE_ROLE_KEY`** in browser/client code or with `NEXT_PUBLIC_` prefix.
13. **Do not add new dependencies** without explicit approval. Prefer existing utilities.

### Verification before claiming completion

14. **Confirm: zero pending tasks, all tests passing, build succeeds, lint clean.**
15. **If you cannot verify a change works (e.g., needs live Supabase or Vercel), state that explicitly.** Do not claim success on untested paths.
16. **For UI changes, start the dev server and test in a browser.** Screenshots or manual confirmation required.
