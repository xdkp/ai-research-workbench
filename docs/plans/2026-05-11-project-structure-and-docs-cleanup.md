# AI Research Workbench Structure and Onboarding Cleanup Plan

Date: 2026-05-11

## Goal

Create one clear onboarding and operating model for the local AI research workspace that combines:

- `hermes-agent` as the agent runtime, CLI, TUI, gateway, skills, memory, tools, and remote execution layer.
- `Fabric` as the prompt-pattern and reusable reasoning workflow library.
- `cc-switch` as the provider/profile/switching manager for Claude Code, Codex, Gemini CLI, OpenCode, and related tools.
- `csp-audit` as the security workflow system of record: scope, tasks, findings, evidence, approvals, DAST, Supabase, report viewer, and final report generation.
- `oh-my-claudecode` and local `.agents` / `.codex` config as supporting Claude Code/Codex customization.

The current problem is not that any one repo is bad. The problem is that the workspace has several powerful upstream projects with separate assumptions, separate install flows, separate config locations, and separate docs. A new machine or new account setup does not yet have a single blessed path.

This document is a local integration plan. It should not be treated as an upstream `hermes-agent`, `Fabric`, or `cc-switch` restructuring proposal unless it is split into small upstream-friendly PRs.

## Current Local Workspace

Expected local root:

```text
/mnt/develop/AI_Research
```

Current observed projects:

```text
AI_Research/
├── Fabric/              upstream prompt-pattern framework
├── cc-switch/           upstream multi-CLI provider/profile manager
├── csp-audit/           local security workflow/control-plane project
├── hermes-agent/        upstream Hermes Agent clone
├── oh-my-claudecode/    Claude Code customization/supporting toolkit
├── .agents/             local agent config/workspace metadata
├── .codex/              local Codex config/workspace metadata
└── .git/                local workspace-level tracking, if intentionally used
```

Important local mount assumption:

```text
/mnt/develop
```

is the ext4 development partition. Active builds, package caches, model files, and agent work should live there rather than on NTFS storage.

## Main Friction

### No Single Start Point

Each repo has its own start point:

```text
hermes
hermes setup
hermes gateway
hermes --tui
fabric
cc-switch desktop app
pnpm scan:poll
report-viewer
Claude Code / Codex config
Vercel / Supabase setup
```

All are valid, but a fresh machine needs one ordered path.

### Upstream Repos Are Mixed With Local Integration Work

`hermes-agent`, `Fabric`, and `cc-switch` are upstream clones. Their docs explain their own product, not this combined local stack. Local integration docs should not be hidden inside only one upstream repo.

### Config Ownership Is Unclear

A new machine needs to know which tool owns which config:

| Area | Likely Owner | Notes |
|---|---|---|
| Agent runtime, memory, skills | Hermes Agent | `~/.hermes`, Hermes config/env, gateway config |
| Prompt patterns | Fabric | Fabric patterns and model/provider config |
| Provider switching | CC Switch | Claude/Codex/Gemini/OpenCode/OpenClaw profiles |
| Security workflow, evidence, approvals, reports | CSP Audit | `report-viewer`, Supabase, Vercel, worker/agent tokens |
| Codex/Claude custom behavior | `.codex`, `.agents`, oh-my-claudecode | Local-only workspace integration |

### Account Recovery Is Not Centralized

Losing or replacing a Vercel, GitHub, provider, Telegram, Slack, Supabase, or model account should not require reading five repos. The workspace needs one recovery guide.

### Product Spine Already Exists In `csp-audit`

The approval and report-generation flow is not a new missing subsystem. It already lives in `csp-audit`.

Current intended spine:

```text
engagement scope
-> approved task
-> agent or scanner execution
-> evidence and generated report material
-> structured finding
-> operator triage/approval
-> submission/export/final report
```

The workspace cleanup should not create another finding database, another approval queue, or another report source of truth. Hermes, Fabric, cc-switch, Codex, and Claude Code should integrate around `csp-audit` as the system of record for security findings and evidence.

## Recommended Workspace-Level Structure

Create a top-level integration documentation layer at the workspace root. Do not start by moving upstream code.

```text
AI_Research/
├── START_HERE.md
├── README.md
├── docs/
│   ├── onboarding/
│   │   ├── new-machine-setup.md
│   │   ├── first-run-checklist.md
│   │   ├── path-and-storage-layout.md
│   │   ├── install-system-deps.md
│   │   └── verify-health.md
│   ├── stack-map/
│   │   ├── component-map.md
│   │   ├── command-map.md
│   │   ├── config-ownership.md
│   │   └── env-var-inventory.md
│   ├── integrations/
│   │   ├── hermes-with-fabric.md
│   │   ├── hermes-with-cc-switch.md
│   │   ├── hermes-with-csp-audit.md
│   │   ├── fabric-pattern-workflow.md
│   │   └── codex-claude-local-config.md
│   ├── operations/
│   │   ├── account-recovery.md
│   │   ├── token-rotation.md
│   │   ├── backup-and-restore.md
│   │   ├── local-storage.md
│   │   └── troubleshooting.md
│   └── development/
│       ├── healthcheck.md
│       ├── test-matrix.md
│       ├── update-upstream-clones.md
│       └── contribution-boundaries.md
├── scripts/
│   ├── doctor.sh
│   ├── check-paths.sh
│   ├── check-tools.sh
│   └── print-env-inventory.sh
├── Fabric/
├── cc-switch/
├── csp-audit/
├── hermes-agent/
└── oh-my-claudecode/
```

This root layer becomes the onboarding point. The upstream repos remain intact.

## Blessed New-Machine Path

The new-machine path should be one checklist, not a tour of every project.

```text
1. Confirm storage layout
   - active workspace: /mnt/develop/AI_Research
   - optional shortcut: ~/Develop -> /mnt/develop

2. Install system dependencies
   - git
   - curl/wget
   - build-essential or distro equivalent
   - Node.js 24
   - pnpm 10
   - Python 3.11+
   - uv
   - ripgrep
   - ffmpeg
   - Playwright browser deps when using csp-audit

3. Clone or update workspace repos
   - hermes-agent
   - Fabric
   - cc-switch
   - csp-audit
   - oh-my-claudecode, if used

4. Install each layer in order
   - Hermes Agent first
   - Fabric second
   - CC Switch third
   - csp-audit fourth
   - optional Claude/Codex customization last

5. Configure minimum secrets
   - model provider key or gateway key
   - GitHub auth if using GitHub workflows
   - Supabase/Vercel only if using csp-audit report viewer or deployment
   - bot tokens only if using Hermes gateway

6. Run health checks
   - hermes doctor
   - fabric --help or equivalent command
   - cc-switch app starts and sees provider profiles
   - csp-audit pnpm tests/build health check
   - gh auth status
   - vercel login only when Vercel is in scope

7. Run first workflow
   - start Hermes CLI/TUI
   - call a Fabric pattern manually
   - verify CC Switch can switch provider profiles
   - run one local csp-audit test scan or report-viewer build

8. Only then configure optional systems
   - Hermes gateway
   - cron
   - remote runtimes
   - Vercel deployments
   - Supabase production project
   - Docker/VPS/systemd
```

## Component Roles

### Hermes Agent

Purpose:

- Main agent runtime and conversation interface.
- TUI/CLI and gateway entry point.
- Memory, skills, tools, cron, MCP, providers, remote runtimes.

Local integration rule:

- Keep upstream clone clean.
- Put workspace-specific Hermes integration docs in `AI_Research/docs/integrations/`, not only inside `hermes-agent/docs/`.
- If changing Hermes upstream docs, split into small PRs.

### Fabric

Purpose:

- Prompt-pattern library and reusable workflow catalog.
- Source of task-specific reasoning patterns.

Local integration rule:

- Treat Fabric patterns as reusable prompt assets that Hermes and Codex can call or reference.
- Document which Fabric patterns are approved for security research, reporting, summarization, and code review.
- Avoid modifying upstream Fabric patterns unless the change is meant as an upstream contribution.

### CC Switch

Purpose:

- Provider/profile manager for Claude Code, Codex, Gemini CLI, OpenCode, and OpenClaw.
- Useful for keeping provider routing and CLI config consistent.

Local integration rule:

- CC Switch should own provider switching docs.
- Workspace docs should explain how CC Switch affects Hermes, Codex, Claude Code, and csp-audit agent workflows.
- Document where it writes config and what files it may modify.

### CSP Audit

Purpose:

- System of record for security engagements, scope, task approvals, findings, evidence, generated reports, submissions, DAST gates, and report-viewer workflows.
- Includes CSP/security-header scanning, pentest/OWASP mapping, Supabase-backed history, worker polling, and agent task control-plane APIs.

Local integration rule:

- Use this as the concrete security workflow and evidence authority.
- Hermes should claim and execute approved/scope-checked tasks from `csp-audit`, then return events, evidence, generated reports, and candidate finding material.
- Fabric should support analysis and report-writing patterns, but should not own evidence records.
- cc-switch should support model/provider selection, but should not own security task state.
- Vercel work should remain optional and clearly separated from local build/test flow.

### oh-my-claudecode / `.agents` / `.codex`

Purpose:

- Local agent/Codex/Claude Code customization and workflow glue.

Local integration rule:

- Keep these as local workspace configuration.
- Document what is safe to sync and what must remain local/private.

## Required Docs To Add First

### 1. `START_HERE.md`

Audience: you on a new machine, or another engineer entering this workspace.

Must answer:

- What is this workspace?
- Which repo do I open first?
- What do I install first?
- What can be skipped?
- What is the first command that proves the stack works?

### 2. `docs/stack-map/component-map.md`

Table:

```text
Component | Role | Language | Entry Point | Config | Required For
```

Example rows:

```text
hermes-agent | agent runtime | Python/Node | hermes | ~/.hermes | agent CLI/TUI/gateway
Fabric | prompt patterns | Go/Markdown | fabric | Fabric config | prompt workflows
cc-switch | provider manager | Tauri/TS/Rust | desktop app | tool config dirs | provider switching
csp-audit | security workflow control plane | Node/Next.js | pnpm test / report-viewer | .env/Vercel/Supabase | scope/tasks/evidence/findings/reports
```

### 3. `docs/stack-map/command-map.md`

One page listing commands by goal:

```text
Goal | Command | Directory | Notes
```

Examples:

```text
Start Hermes | hermes | any | after install
Diagnose Hermes | hermes doctor | any | first health check
Run Fabric pattern | fabric ... | any | depends on Fabric setup
Run CSP tests | pnpm test | csp-audit | no Vercel needed
Build report viewer | pnpm --prefix report-viewer build | csp-audit | no Vercel account needed
Check GitHub auth | gh auth status | any | needed for GitHub workflows
```

### 4. `docs/stack-map/env-var-inventory.md`

Split by scenario:

- Minimal local agent
- Fabric usage
- CC Switch provider profiles
- CSP Audit local-only
- CSP Audit Supabase/Vercel
- Hermes gateway bots
- CI/GitHub Actions

Columns:

```text
Variable | Required For | Required? | Where Set | Rotate When | Notes
```

### 5. `docs/integrations/hermes-with-fabric.md`

Describe how Fabric patterns are used from Hermes/Codex workflows:

- manual call
- copied/adapted pattern
- skill wrapper
- reporting/summarization workflow
- security-research workflow

### 6. `docs/integrations/hermes-with-cc-switch.md`

Describe provider/profile ownership:

- what CC Switch changes
- which tools read those configs
- how to avoid profile drift
- how to recover if a provider config breaks

### 7. `docs/integrations/hermes-with-csp-audit.md`

Describe how Hermes integrates into the existing `csp-audit` control plane:

```text
csp-audit defines engagement scope
-> csp-audit portal creates task
-> task passes approval/scope gate
-> Hermes agent claims task
-> Hermes executes allowed workflow
-> Hermes posts events/evidence/generated report material
-> csp-audit stores structured finding and triage status
-> operator confirms/rejects/edits finding
-> csp-audit exports or generates final report from approved material
```

Must include:

- what runs locally
- what requires Supabase
- what requires Vercel
- which tokens are involved
- how to run without Vercel
- which csp-audit tables/routes own task, evidence, finding, and report state
- which fields are operator-approved vs agent-generated

### 8. `docs/operations/account-recovery.md`

Cover replacing accounts without code changes:

- Vercel account/project
- Supabase project
- GitHub account/repo connection
- model provider key
- Telegram/Slack/Discord bot
- CC Switch provider profile

For each:

```text
What breaks | What to rotate | What to recreate | What repo code should not change
```

## Cleanup Policy For Upstream Clones

Because `hermes-agent`, `Fabric`, and `cc-switch` are upstream clones:

- Do not reorganize their source tree for local convenience.
- Keep local integration docs outside upstream repos where possible.
- If a doc improvement belongs upstream, make a small branch and PR.
- Do not commit lockfile changes caused only by local install unless intentional.
- Keep local `.env`, provider profiles, tokens, and machine paths out of upstream commits.

## Short-Term Implementation Phases

### Phase 1: Workspace Onboarding Layer

Create:

```text
AI_Research/START_HERE.md
AI_Research/docs/stack-map/component-map.md
AI_Research/docs/stack-map/command-map.md
AI_Research/docs/stack-map/config-ownership.md
AI_Research/docs/stack-map/env-var-inventory.md
AI_Research/docs/onboarding/new-machine-setup.md
```

No upstream repo code moves.

### Phase 2: Integration Docs

Create:

```text
AI_Research/docs/integrations/hermes-with-fabric.md
AI_Research/docs/integrations/hermes-with-cc-switch.md
AI_Research/docs/integrations/hermes-with-csp-audit.md
AI_Research/docs/integrations/codex-claude-local-config.md
```

### Phase 3: Healthcheck Scripts

Create read-only scripts:

```text
AI_Research/scripts/check-paths.sh
AI_Research/scripts/check-tools.sh
AI_Research/scripts/doctor.sh
```

Rules:

- read-only by default
- no installs
- no account login
- no token printing
- report missing tools and paths clearly

### Phase 4: Account Recovery And Operations

Create:

```text
AI_Research/docs/operations/account-recovery.md
AI_Research/docs/operations/token-rotation.md
AI_Research/docs/operations/backup-and-restore.md
AI_Research/docs/operations/local-storage.md
AI_Research/docs/operations/troubleshooting.md
```

### Phase 5: Upstream Contribution Triage

Only after the local integration layer is clear:

- For `hermes-agent`, propose `new-machine-setup.md` or README navigation improvements upstream.
- For `Fabric`, avoid PRs unless pattern docs are clearly reusable.
- For `cc-switch`, upstream only provider/profile documentation improvements.
- For `csp-audit`, continue local project docs because that repo is your active build.

## Done Criteria

The cleanup is successful when:

- A fresh machine can start from `AI_Research/START_HERE.md` and reach a working Hermes/Fabric/CC Switch/CSP Audit local setup without guessing which repo to open first.
- The user can tell which tool owns each config file and provider key.
- The user can run a single read-only healthcheck that reports what is installed, missing, misconfigured, or optional.
- Vercel/Supabase/GitHub account replacement is documented without implying code changes are required.
- Upstream clones stay clean unless changes are intentionally prepared as upstream PRs.
- Local docs clearly separate local-only integration knowledge from upstream project documentation.

## Immediate Next Step

Do not move code yet.

Create the workspace-level onboarding layer first:

```text
AI_Research/START_HERE.md
AI_Research/docs/onboarding/new-machine-setup.md
AI_Research/docs/stack-map/component-map.md
AI_Research/docs/stack-map/command-map.md
AI_Research/docs/stack-map/config-ownership.md
AI_Research/docs/stack-map/env-var-inventory.md
```

That gives the whole stack one front door before deeper cleanup begins.
