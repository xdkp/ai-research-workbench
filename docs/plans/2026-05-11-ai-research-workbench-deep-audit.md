# AI Research Workbench Deep Audit

Date: 2026-05-11

## Executive Summary

The combined workspace is powerful but not yet operationally mature as one system. The individual upstream projects have substantial functionality and, in several cases, strong standalone hygiene. `csp-audit` already contains the security workflow spine for scope, tasks, findings, evidence, approvals, and reports. The remaining gap is at the workspace integration layer: there is no single source of truth for onboarding, config ownership, secrets, health checks, account recovery, or how Hermes, Fabric, cc-switch, csp-audit, Codex, and Claude Code should work around that control plane.

The most important improvement is not Kubernetes or a large code restructure. The best first move is to create a workspace-level operating layer under `/mnt/develop/AI_Research`: `START_HERE.md`, stack maps, env-var inventory, healthcheck scripts, and integration docs. Docker Compose should be introduced only for repeatable background services. Kubernetes is premature.

## Audit Scope

Audited local workspace:

```text
/mnt/develop/AI_Research
```

Observed components:

```text
Fabric/              prompt-pattern framework, upstream clone
cc-switch/           provider/profile manager, upstream clone
csp-audit/           active security scanner/report-viewer/control-plane project
hermes-agent/        agent runtime, upstream clone
oh-my-claudecode/    Claude Code customization toolkit, upstream clone/support repo
.agents/             local agent metadata/config
.codex/              local Codex metadata/config
```

This audit treats the workspace as a combined AI security research workbench, not as one monorepo. `hermes-agent`, `Fabric`, and `cc-switch` should be treated as upstream clones unless intentionally forked or patched.

## Current Strengths

- The individual projects are capable and already cover major roles: agent runtime, prompt patterns, provider switching, security scanning, dashboards, and Claude/Codex customization.
- `hermes-agent` has mature signals: `pyproject.toml`, `uv.lock`, Docker assets, CI workflows, security workflows, docs site, tests, and explicit optional extras.
- `csp-audit` has the concrete security workflow and should remain the system of record: engagements, scope, agent tasks, approval status, task events, generated reports, structured findings, triage status, submissions, scanner output, OWASP/pentest mapping, report-viewer, Supabase schema, DAST gates, and OpenAPI/docs.
- `cc-switch` is a natural owner for provider/profile switching across multiple AI CLIs.
- `Fabric` provides a rich prompt-pattern library that can become the reusable reasoning layer.
- The workspace now lives on `/mnt/develop`, an ext4 partition appropriate for Linux builds and dependency trees.

## Product Spine Confirmation

`csp-audit` already lays down the core workflow the combined system needs:

```text
scope -> approved task -> execution evidence -> structured finding -> operator triage -> generated/exported report
```

The relevant `csp-audit` ownership areas are already present:

- `engagements` for program/scope/rules.
- `agent_tasks` for approved or pending work.
- `agent_task_events` for execution trace.
- `generated_reports` for agent-produced markdown/JSON report material.
- `findings` for structured findings with evidence and triage status.
- `submissions` and duplicate tracking for external reporting lifecycle.
- report-viewer APIs/components for tasks, engagements, findings, chains, exports, and reports.

So the best-practice target is not to create another approval/reporting layer in Hermes or Fabric. The target is to make Hermes, Fabric, cc-switch, Codex, and Claude Code feed the existing `csp-audit` spine cleanly.

## Critical Gaps

### 1. No Workspace-Level Front Door

Problem:

Each repo has its own README and entry points, but the combined workbench has no `START_HERE.md` or root operating manual.

Impact:

A fresh machine setup requires guessing between `hermes`, `fabric`, `cc-switch`, `pnpm test`, `vercel`, `Supabase`, and Claude/Codex config. This is the primary onboarding failure.

Recommendation:

Create:

```text
/mnt/develop/AI_Research/START_HERE.md
/mnt/develop/AI_Research/docs/onboarding/new-machine-setup.md
/mnt/develop/AI_Research/docs/stack-map/component-map.md
/mnt/develop/AI_Research/docs/stack-map/command-map.md
```

Make the first documented path:

```text
storage check -> system deps -> install Hermes -> install Fabric -> install cc-switch -> install csp-audit -> configure minimum secrets -> run doctor -> run first workflow
```

### 2. Config Ownership Is Undefined

Problem:

Multiple tools can own overlapping provider/model/auth config:

```text
Hermes config/env
cc-switch provider profiles
Codex config
Claude Code config
Fabric model/provider config
csp-audit Vercel/Supabase/agent tokens
```

Impact:

The stack can drift into inconsistent states where Hermes, Codex, Claude Code, Fabric, and cc-switch each believe a different provider/model/profile is active.

Recommendation:

Define ownership:

| Config Area | Owner | Notes |
|---|---|---|
| Provider/profile switching for coding CLIs | cc-switch | Preferred owner where supported |
| Agent runtime config, memory, gateway | Hermes | `~/.hermes` and Hermes-specific env |
| Prompt patterns | Fabric | Pattern source, not long-term memory owner |
| Security workflow/evidence/report state | csp-audit | Supabase, Vercel, worker/agent tokens, findings, triage, generated reports |
| Local assistant behavior | `.codex`, `.agents`, oh-my-claudecode | Local-only workspace integration |

Create `docs/stack-map/config-ownership.md`.

### 3. Environment Variables Are Spread Across Repos

Problem:

Env vars exist in several systems: model provider keys, bot tokens, Vercel, Supabase, GitHub, worker tokens, agent tokens, gateway keys, and CLI profile secrets.

Impact:

New account recovery and fresh-machine setup are fragile. Secrets can be duplicated, stale, or placed in the wrong repo.

Recommendation:

Create `docs/stack-map/env-var-inventory.md` organized by scenario:

- Minimal local Hermes
- Hermes gateway
- Fabric only
- cc-switch provider profiles
- csp-audit local-only
- csp-audit Supabase/Vercel
- GitHub Actions/CI
- Model hosting/Ollama

Use columns:

```text
Variable | Owner | Required For | Where Set | Example Shape | Rotate When | Notes
```

### 4. Workspace Root Git State Is Invalid

Observation:

`/mnt/develop/AI_Research/.git` exists as an empty directory, but `git status` at the workspace root fails.

Impact:

This creates confusion: the workspace looks like a repo but is not one. Tools may behave unexpectedly, and users may assume changes are tracked when they are not.

Recommendation:

Choose one:

1. If the workspace root should be tracked, initialize it properly and ignore child repo internals/build artifacts.
2. If not, remove or rename the empty `.git` directory after confirming it contains no useful data.

Best practice for this setup: keep child repos as separate repos and use root docs/scripts without pretending it is a monorepo, unless you intentionally create a meta-repo.

### 5. Upstream Clone Hygiene Is Weak

Observation:

`Fabric` shows a massive dirty tree:

```text
772 files changed, 114570 insertions(+), 114570 deletions(-)
```

This pattern strongly suggests line-ending or mechanical rewrite noise.

`hermes-agent` also has local dirty lockfiles:

```text
ui-tui/packages/hermes-ink/package-lock.json
web/package-lock.json
```

Impact:

Dirty upstream clones make it hard to pull updates, create clean PRs, or tell local integration notes from accidental changes.

Recommendation:

- Do not build integration docs by modifying upstream clone internals.
- Quarantine local notes in workspace-level docs.
- For Fabric, inspect line-ending settings before any commit. Avoid committing the 772-file diff.
- For Hermes lockfiles, keep or discard only after identifying what command changed them.

### 6. Local Build Artifacts Are Too Large

Observation:

Project sizes:

```text
oh-my-claudecode    93M
Fabric             181M
hermes-agent       275M
csp-audit          758M
cc-switch           38G
```

`cc-switch` size is almost entirely:

```text
cc-switch/src-tauri/target    37G
```

Impact:

New-machine backup, rsync, indexing, and disk usage become noisy. It also increases the chance that generated artifacts are mistaken for source.

Recommendation:

- Keep `src-tauri/target` ignored, but document it as disposable build cache.
- Add workspace cleanup guidance:

```text
cargo clean inside cc-switch/src-tauri when reclaiming space
pnpm store prune when needed
remove project node_modules only when reproducible from lockfiles
```

- Add `docs/operations/local-storage.md` with what is source vs cache.

### 7. Health Checks Are Fragmented

Problem:

Each repo has its own checks:

- `hermes doctor`
- Hermes pytest/ruff/ty/scripts
- csp-audit `pnpm test`, `ops:status`, `ops:validate`, report-viewer lint/build/vitest
- cc-switch typecheck/test/build
- Fabric Go tests and web checks
- oh-my-claudecode tests/lint/build

Impact:

There is no one command to answer: "Is my whole workbench ready?"

Recommendation:

Create read-only workspace scripts:

```text
AI_Research/scripts/check-paths.sh
AI_Research/scripts/check-tools.sh
AI_Research/scripts/doctor.sh
AI_Research/scripts/check-projects.sh
```

Rules:

- Do not install dependencies.
- Do not print secrets.
- Do not call external account APIs unless explicitly named.
- Print PASS/WARN/FAIL by component.

### 8. Integration Boundaries Are Not Documented

Problem:

The intended data/control flow is clear in discussion but not formalized:

```text
cc-switch controls profiles
Fabric provides patterns
Hermes executes workflows
csp-audit owns security tasks, evidence, findings, approvals, and reports
Codex/Claude Code assist coding
```

Impact:

Without written boundaries, each tool can become "the place where AI workflow lives," causing duplicate configs, duplicate memory, duplicate reports, and duplicate task queues. The most important boundary is that `csp-audit` remains the only system of record for security evidence, finding status, and reportable output.

Recommendation:

Create integration docs:

```text
docs/integrations/hermes-with-fabric.md
docs/integrations/hermes-with-cc-switch.md
docs/integrations/hermes-with-csp-audit.md
docs/integrations/codex-claude-local-config.md
```

Define the rule:

```text
cc-switch = provider/profile switchboard
Hermes = agent runtime and long-running executor
Fabric = reusable pattern library
csp-audit = security task/evidence/finding/report control plane and system of record
Codex/Claude Code = coding executors and repo assistants
```

### 9. Account Recovery Is Missing At Workspace Level

Problem:

Losing a Vercel, Supabase, GitHub, provider, or bot account currently requires reading multiple project docs.

Impact:

Recovery becomes risky and may lead to unnecessary code changes when only account IDs/secrets need replacement.

Recommendation:

Create `docs/operations/account-recovery.md` with per-account checklists:

- Vercel account/project
- Supabase project
- GitHub account/repo connection
- model provider account/key
- Telegram/Slack/Discord bot
- cc-switch provider profile

For each:

```text
What breaks | What to rotate | What to recreate | Where to update | What code should not change
```

### 10. Docker Is Useful But Not Yet Organized

Observation:

Container assets exist mainly in Hermes and oh-my-claudecode benchmark. The combined workspace has no root Compose profile.

Impact:

Long-running services can be hard to reproduce, but introducing Kubernetes now would overcomplicate the system.

Recommendation:

Use Docker Compose later for services only:

```text
csp-report-viewer
csp-scan-worker
supabase-local, optional
hermes-gateway, optional
ollama/model service, optional
```

Keep native on host:

```text
VS Code / Codex / Claude Code
cc-switch GUI
Hermes CLI/TUI
Fabric CLI
```

Avoid Kubernetes until there is a multi-user or multi-node deployment requirement.

## Best-Practice Target Operating Model

### Documentation Model

Use three doc layers:

1. Workspace docs: how the combined stack works locally.
2. Project docs: how each repo works on its own.
3. Upstream docs: untouched unless contributing upstream.

Workspace docs should be the first door. Project docs should be deep links.

### Repository Model

Keep each upstream repo separate:

```text
Fabric/.git
cc-switch/.git
hermes-agent/.git
oh-my-claudecode/.git
csp-audit/.git or local active repo
```

Add a workspace meta-layer only if needed:

```text
AI_Research/START_HERE.md
AI_Research/docs/**
AI_Research/scripts/**
```

If a root meta-repo is created, it must ignore child repo source trees or use submodules/worktrees intentionally.

### Configuration Model

Do not let every tool own every key.

Preferred ownership:

```text
cc-switch: coding CLI provider profiles
Hermes: agent runtime config, memory, gateway settings
Fabric: pattern catalog config
csp-audit: Supabase/Vercel/security workflow config
Codex/Claude local config: assistant behavior only
```

### Service Model

Native first, containers for services:

```text
Native: interactive CLIs, GUI apps, editor integrations
Docker Compose: repeatable daemons and local services
Kubernetes: future team/production lab only
```

### Security Model

- No secrets in repos.
- One env inventory by scenario.
- Token rotation docs.
- Account recovery docs.
- Clear separation between local-only, CI, and deployment secrets.
- Agent task approvals, target scope gates, finding triage, evidence records, and reportable output stay in csp-audit.

### CI/Quality Model

Workspace-level health should not replace project-level CI. It should orchestrate it.

Recommended check tiers:

```text
Tier 0: check paths and required tools
Tier 1: read-only config validation
Tier 2: fast tests/builds per active project
Tier 3: optional integration checks requiring accounts/services
```

## Priority Recommendations

### P0 - Stop Confusion And Data Loss Risk

1. Fix or remove the empty workspace `.git` directory.
2. Do not commit the Fabric 772-file mechanical diff.
3. Document `cc-switch/src-tauri/target` as disposable cache.
4. Keep upstream clone changes separate from local integration docs.

### P1 - Create The Missing Workbench Front Door

1. Create `/mnt/develop/AI_Research/START_HERE.md`.
2. Create component map, command map, config ownership, env inventory.
3. Create new-machine setup checklist.
4. Create account recovery guide.

### P2 - Define Integration Contracts

1. Hermes with Fabric: pattern usage and skill wrapping.
2. Hermes with cc-switch: provider/profile boundary.
3. Hermes with csp-audit: task claim, approval, scope, evidence return, candidate finding handoff, and generated report material.
4. Codex/Claude local config: what is local and what is shared.

### P3 - Add Read-Only Workspace Health Checks

1. `scripts/check-paths.sh`
2. `scripts/check-tools.sh`
3. `scripts/doctor.sh`
4. `scripts/check-projects.sh`

### P4 - Containerize Only Stable Services

1. Start with optional Docker Compose for csp-audit services.
2. Add Hermes gateway only after config ownership is documented.
3. Add Ollama/model service only if model hosting is in active use.
4. Do not introduce Kubernetes yet.

## Suggested 30-Day Roadmap

### Week 1

- Create workspace `START_HERE.md` and docs skeleton.
- Document component roles and command map.
- Clean or quarantine invalid root `.git` and dirty upstream clone state.

### Week 2

- Write env-var inventory and config ownership docs.
- Write account recovery and token rotation docs.
- Add read-only `check-paths.sh` and `check-tools.sh`.

### Week 3

- Write Hermes/Fabric, Hermes/cc-switch, and Hermes/csp-audit integration docs.
- Add `doctor.sh` that summarizes health across projects.
- Decide if csp-audit should be the first Docker Compose service group.

### Week 4

- Add optional Compose profile for stable background services.
- Validate fresh-machine path on the ext4 workspace.
- Turn upstream-improvement ideas into separate, small PR candidates only if needed.

## What Not To Do Yet

- Do not reorganize upstream source trees.
- Do not introduce Kubernetes.
- Do not centralize all config into one mega `.env`.
- Do not make cc-switch own Hermes runtime memory or csp-audit evidence.
- Do not make Fabric own execution state or reporting records.
- Do not commit generated build artifacts or mechanical line-ending diffs.

## Bottom Line

The stack is not missing power. It is missing operating discipline at the workspace level.

The right shape is:

```text
cc-switch     -> provider/profile switchboard
Fabric        -> reusable prompt-pattern library
Hermes        -> agent runtime and long-running executor
csp-audit     -> security task/evidence/finding/report system of record
Codex/Claude  -> coding executors and repo assistants
```

The immediate best-practice move is to build one workspace onboarding and operations layer around those roles, while keeping upstream clones clean.
