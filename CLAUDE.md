# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Session Startup (RUN FIRST — before any other action)

At the start of every session, Claude MUST:

1. **Load memory.** Read `/home/m0bious/.claude/projects/-mnt-develop-AI-Research/memory/MEMORY.md` and all files it links to (user profile, current work, feedback, references). Do not skip this — the user's machine freezes and sessions can end abruptly. Memory is the only continuity between sessions.

2. **Load oh-my-claudecode.** List agents at `oh-my-claudecode/agents/` and skills at `oh-my-claudecode/skills/`. These are the development toolchain — 19 specialist agents (planner, code-reviewer, git-master, qa-tester, verifier, etc.) and skills (autopilot, debug, etc.). Use them instead of working directly whenever appropriate.

3. **Check git state across all repos.** Run `git status` in the root and each child repo. Understand what branch is active and whether anything is dirty before acting.

4. **Report what you found.** Tell the user: current branch, dirty files, available agents/skills, and what was being worked on last (from memory). Then ask what to continue with.

**Hard rule:** Do not write, edit, push, or execute anything until these four steps are complete.

This is a **meta-repo** at `/mnt/develop/AI_Research`. The root tracks only workspace-level docs, scripts, and onboarding — not child project source code. Each child project keeps its own Git history and remote:

| Project | Role | Primary Remote |
|---------|------|----------------|
| `offensive-research-portal` | Security workflow system of record (Next.js + Supabase) | `github.com/xdkp/offensive-research-portal.git` |
| `hermes-agent` | Agent runtime, CLI/TUI, gateway, skills (Python) | `github.com/NousResearch/hermes-agent.git` |
| `Fabric` | Prompt-pattern library (Go, Markdown) | `github.com/danielmiessler/Fabric.git` |
| `cc-switch` | Provider/profile switching for AI CLI tools (Tauri/Rust) | `github.com/xdkp/cc-switch-custom.git` |
| `oh-my-claudecode` | Claude Code customization/support tooling | `github.com/Yeachan-Heo/oh-my-claudecode.git` |
| `pentest-ai-agents` | Methodology/prompt reference (read-only, do not vendor) | `github.com/0xSteph/pentest-ai-agents` |
| `uqlm` | Uncertainty quantification for hallucination detection (Python) | `github.com/cvs-health/uqlm` |

Child repos are in `.gitignore`. Do not force them into the root repo.

## Project Goal

Build a **local-first pentest workbench** where the operator stays in control.
Hermes executes tasks, Fabric drafts/enriches reports, cc-switch chooses the right
model for each step, Portal stores and reviews redacted workflow records, and
UQLM helps detect hallucinated or weak outputs. Cloud models may assist with
heavy reasoning only through redacted, schema-gated payloads; raw sensitive
evidence stays local unless the operator explicitly approves sharing.

The operator is the final authority. Models propose, verify, summarize, and
reduce search/proof burden; they do not self-authorize destructive actions,
data access, denial-of-service behavior, or out-of-scope testing.

## System of Record

`offensive-research-portal` is the single source of truth for security workflow data. The pipeline is:

```
scope -> approved task -> execution evidence -> structured finding -> operator triage -> final report/export
```

**Hard rules:**
- Do not create a second cloud/workflow source of truth outside `offensive-research-portal`.
- Local SQLite stores are allowed only for operational state: crash recovery,
  sync queues, local-only redaction registry, proof-card drafts, validation
  attempts, scanner cache, and offline retry. These local tables are not the
  canonical reporting system.
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

### offensive-research-portal (run from `offensive-research-portal/`)
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
docker compose --env-file docker-compose.env --profile offensive-research-portal --profile hermes-gateway up
```

### Other tools
```bash
fabric --help       # Fabric CLI (prompt patterns)
ollama list         # Check if Ollama daemon is reachable
```

## Architecture

### Portal + Supabase data layer
- **Portal** (`offensive-research-portal/report-viewer`): Next.js 15 app on Vercel. Reads from Supabase, renders dashboards and triage UI.
- **Database**: Supabase cloud PostgreSQL. Schema in `offensive-research-portal/supabase/schema.sql` (9+ tables: scans, engagements, findings, agent_tasks, agent_instances, agent_task_events, generated_reports, submissions, submission_duplicates, plus workflow_templates, workflow_plans, model_configs, audit_log, approval_policies, system_config).
- **Local worker** (`offensive-research-portal/csp-playwright-audit.js`): Playwright BFS scanner that polls the portal API for queued scans, executes them, and uploads results. Authenticates with `SCAN_WORKER_TOKEN`.

### Agent bridge
- **Hermes gateway** (`hermes-agent/gateway/`): Claims tasks from offensive-research-portal agent API (`POST /api/agent/tasks/claim`), executes them, posts events and generated reports. Uses `AGENT_TOKEN` for auth.
- **Heartbeat protocol**: Hermes posts to `POST /api/agent/heartbeat` with agent state (idle/busy/paused/waiting_approval). No heartbeat within 60s → agent marked stale.
- **Task execution modes**: `receipt` (safe default, writes receipt report), `analysis` (proof-driven enrichment pipeline with redacted cloud briefs, UQLM checks, validation cards, and local proof storage).

### Operator Authority Policy (non-negotiable)
- Hermes may propose HIGH/CRITICAL actions but requires explicit operator approval before execution.
- Approval is action-level: a Medium finding with a destructive action still requires approval.
- Default-deny if policy evaluation fails. Out-of-scope targets are hard-blocked.
- All approval/rejection decisions are immutable, timestamped, and audited in `audit_log`.

### Local-first deployment
- Primary workflow: `docker compose up` bootstraps local runtime (cc-switch, Fabric, Hermes, scanners, local models).
- Portal can be optionally hosted (Vercel) for read-only reports and operator console.
- Execution components (model runtimes, PoC validation, Fabric patterns, Hermes agents) remain under operator control on local infrastructure.
- Cloud assistance is allowed only after the outbound cloud boundary validates a
  redacted DTO such as `RedactedFindingBrief/v1` with `SecurityFactGraph/v1`.
  Raw IPs, internal domains, secrets, bearer tokens, raw HTTP requests, and PII
  must fail closed before provider dispatch or Portal upload.

## Current Release Focus

Active implementation is **Release E — Proof-Driven Automation** from `plan.md`.

Completed in the current Release E path:
- Safe validation flow proof: high-impact finding → low-risk proof card → operator-visible evidence → no destructive action.
- `SecurityFactGraph/v1` builder for cloud-safe structured context.
- Outbound cloud proxy/schema gate before Fabric/UQLM/cloud model calls.
- Local Hermes proof storage: `validation_cards_local`, `validation_attempts_local`, local-only `redaction_registry`, and `sync_queue` payloads.
- Sync worker reconciliation for offline-drained validation-card and validation-attempt queue rows.

Next work:
- Add compatibility migration from legacy `action_class` / `risk_level` to `validation_action_risk` / `vulnerability_severity`.
- Continue Portal/cc-switch proof queue and model capability governance work after the storage and migration layer is stable.

UQLM is a quality gate, not a truth oracle. It reduces hallucination/noise by
checking consistency and grounding, but operator review and policy boundaries
remain decisive.

## Key Files

| File | Purpose |
|------|---------|
| `plan.md` | Product architecture, team design, and safety foundation |
| `offensive-research-portal/plan.md` | Numbered Phase 0-12 implementation roadmap |
| `docker-compose.yml` | Local Docker Compose entry point |
| `docker-compose.env.example` | Template for local secrets (committed, placeholder values) |
| `docs/stack-map/` | Component map, repository manifest, command map, env var inventory, config ownership |
| `docs/integrations/` | Integration contracts between components |
| `docs/operations/current-workspace-status.md` | Live status snapshot of entire workspace |
| `docs/onboarding/new-machine-setup.md` | New-machine checklist |
| `offensive-research-portal/docs/agent-task-contract.md` | Agent API contract |
| `offensive-research-portal/docs/openapi.yaml` | OpenAPI 3.0 spec for Agent API |

## Secret Management

- Local dev: `docker-compose.env` (gitignored). Template: `docker-compose.env.example` (committed).
- Production: Vercel env vars + GitHub Actions secrets.
- Never in code: API keys, tokens, passwords.
- Never expose `SUPABASE_SERVICE_ROLE_KEY` with `NEXT_PUBLIC_` prefix.
- Agent token: shared secret between Hermes and offensive-research-portal API (`AGENT_TOKEN`).
- Emergency rotation: `docs/operations/account-recovery.md`.

## Handling Rules for Child Repos

- **offensive-research-portal**: Active development. Do not reset or discard changes. Branch: `develop`.
- **hermes-agent**: Upstream clone. Local Docker gateway files (`Dockerfile.gateway`, `gateway-bootstrap.sh`, `offensive-research-portal-heartbeat.py`, `offensive-research-portal-task-runner.py`) are workbench integration work — do not push upstream casually.
- **Fabric**: Keep clean unless opening an upstream contribution branch.
- **cc-switch**: Clean repo. Has large Rust build cache (`src-tauri/target`, ~37GB) — clean only when storage pressure requires it.
- **oh-my-claudecode**: Reference/config repo.
- **pentest-ai-agents**: Reference-only for methodology extraction. Do not vendor contents or push changes casually.
- **uqlm**: Upstream clone (Apache 2.0). Used by Hermes for enrichment verification. Install via pip into Hermes container. Do not push changes upstream casually.

## CI/CD (offensive-research-portal)

- `develop` branch: runs tests, lint, build, preview DAST gate.
- `main` branch: runs tests, lint, build, production deploy to Vercel, production DAST evidence workflow with HIGH-severity gate.
- Deploy controller: GitHub Actions (`vercel deploy --prebuilt --prod`). Vercel Git auto-deploy is intentionally disconnected.

## Agent Development Rules

These rules apply to Claude Code when working on any project in this workspace. They ensure every change is tested, verified, and safe before merge.

### Current workflow for this workspace

1. Work on a feature branch for each repo; do not mix unrelated repo changes into one push.
2. Before pushing, run the relevant local verification for the touched repo(s) and fix failures locally.
3. Push only to the `xdkp` fork remotes for child repos.
4. Open a PR to trigger CI, then check the resulting GitHub Actions run and fix any failures before moving on.
5. Keep root docs updates in the root repo and child-repo changes in the child repo unless the change truly spans both.
6. Use `apply_patch` for text-file edits. Do not use notebook/file-generation tools to modify normal repository source or docs files.
7. When a task depends on prior local state, preserve untracked scratch files unless the user explicitly asks to remove them.

### Branch and commit rules

1. **Default: never push directly to `main` or `develop`.** Always work in a feature branch. Direct main/develop pushes are allowed only when the user explicitly overrides this for a specific release, hotfix, or Vercel/main test.
2. **Create a new commit for each completed feature or fix.** Do not amend published commits.
3. **Never skip hooks** (`--no-verify`, `--no-gpg-sign`) unless explicitly instructed.
4. **Write conventional commit messages.** Subject under 70 characters, body explaining WHY.

### Pre-PR verification — run before opening a pull request

For every change, run the project's verification commands locally and confirm they pass before opening a PR:

**offensive-research-portal (from `offensive-research-portal/`):**
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
