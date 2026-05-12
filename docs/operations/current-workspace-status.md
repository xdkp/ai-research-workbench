# Current Workspace Status

Date checked: 2026-05-12

Workspace root:

```text
/mnt/develop/AI_Research
```

This document records the current state of the combined AI Research Workbench so future changes do not have to rediscover the same layout, ownership, and risks.

## Workspace Meta-Repo

The workspace root is now a valid Git repository.

Current committed baseline before planning archive updates:

```text
62127f2 Add repository manifest and repo health check
```

Root remote:

```text
https://github.com/xdkp/ai-research-workbench.git
```

The root repository is a meta-layer only. It tracks shared onboarding, integration docs, archived planning records, and read-only health scripts. Historical planning records are archived in `docs/plans/`. It does not own the source history of the child projects.

Tracked workspace layer:

```text
README.md
START_HERE.md
docs/
  docs/plans/
scripts/
.gitignore
```

Ignored child repositories:

```text
Fabric/
cc-switch/
csp-audit/
hermes-agent/
oh-my-claudecode/
```

## System Purpose

The combined workspace is intended to support security finding and analysis with human approval before final reporting.

The intended workflow is:

```text
scope
-> task
-> scan / manual analysis
-> evidence
-> finding draft
-> operator review
-> approval
-> final report material
-> report export
```

`csp-audit` is the system of record for this workflow. Hermes, Fabric, cc-switch, Codex, and Claude Code are support tools around that control plane.

## Child Project Roles

| Project | Role | Ownership status |
| --- | --- | --- |
| `csp-audit` | Security control plane, scans, findings, approvals, report viewer, DAST gate | Active local development, currently clean after hardening commits |
| `hermes-agent` | Agent runtime, orchestration, skills, gateway, CLI/TUI/web surfaces | Upstream clone, keep clean |
| `Fabric` | Prompt/pattern library and analysis patterns | Upstream clone, keep clean |
| `cc-switch` | Claude Code / Codex style switching and local helper tooling | Clean child repo, has large Rust build cache |
| `oh-my-claudecode` | Claude Code configuration/plugin reference | Clean child repo |

## Current Child Repo State

### `Fabric`

Current status:

```text
clean
```

Handling rule:

```text
Keep Fabric clean unless an explicit upstream contribution branch is opened.
```

Earlier line-ending noise was cleaned. Do not reintroduce mechanical diffs.

### `cc-switch`

Current status:

```text
clean
```

Known large cache:

```text
/mnt/develop/AI_Research/cc-switch/src-tauri/target
```

Observed size:

```text
37G
```

This is disposable Rust/Cargo build output. It can be cleaned later with:

```bash
cd /mnt/develop/AI_Research/cc-switch/src-tauri
cargo clean
```

Do not clean it automatically during normal workspace checks.

### `csp-audit`

Current status:

```text
clean
```

Recently completed local work:

```text
control-plane hardening
task approval behavior
target and engagement scope validation
atomic scan claiming RPC
agent token misconfiguration handling
route-level tests
Preview DAST secret skipping behavior
documentation updates
```

Handling rule:

```text
This repo is active work. Do not reset or discard changes.
```

Vercel account/project work remains paused, but local tests/builds and control-plane hardening are committed.

### `hermes-agent`

Current status:

```text
clean
```

Handling rule:

```text
Treat this as an upstream clone. Keep workbench planning docs in the root meta-repo under docs/plans/.
```

### `oh-my-claudecode`

Current status:

```text
clean
```

Handling rule:

```text
Use as reference/config support unless a direct integration task is opened.
```

## Mount And Storage State

Development workspace:

```text
/mnt/develop
```

Expected filesystem:

```text
ext4
```

Current target:

```text
/mnt/develop/AI_Research
```

This is the preferred place for active Linux development, builds, caches, local models, datasets, and report work.

Legacy/archive storage:

```text
/mnt/new_volume
```

Expected filesystem:

```text
ntfs3
```

Use this for old files, archives, installers, VMs, media, and Windows-era data. Do not use it as the main Linux build workspace.

## Tool State

Required tools currently found:

```text
git
rg
node
pnpm
python3
```

Useful tools currently found:

```text
cargo
gh
vercel
docker
ollama
```

Optional tools missing or not on `PATH`:

```text
uv
go
ffmpeg
hermes
fabric
```

Notes:

- `vercel` is installed, but Vercel account/project actions are paused.
- `hermes` and `fabric` may exist as source repos but are not currently installed as shell commands.
- Missing optional tools should not block `csp-audit` development unless a specific task needs them.

## Vercel Status

Vercel work is currently on hold.

Do not run:

```bash
vercel login
vercel link
vercel deploy
vercel env pull
```

until account ownership and project configuration are intentionally resolved.

The repo can continue local development without Vercel.

## Safe Actions

Safe next actions:

```text
run ./scripts/doctor.sh
edit workspace docs
improve onboarding docs
continue csp-audit local development
run local csp-audit tests
inspect Fabric dirty state read-only
inspect Hermes lockfile changes read-only
```

Safe cleanup candidates, only when explicitly requested:

```text
cc-switch/src-tauri/target via cargo clean
temporary logs
generated local build outputs
```

## Do Not Do Yet

Do not do these without a specific decision:

```text
do not move all projects into a new monorepo
do not delete child project .git folders
do not reset dirty child repos
do not commit Fabric changes blindly
do not clean cc-switch Rust target unless space is needed
do not perform Vercel login/deploy/link actions
do not move Docker root data onto /mnt/develop yet
```

## Recommended Next Work

Recommended next sequence:

1. Commit this status document in the workspace meta-repo.
2. Add a top-level `docs/operations/project-state-ledger.md` if child repo state needs to be tracked over time.
3. Inspect `csp-audit` local changes and decide the next implementation milestone.
4. Inspect `hermes-agent` lockfile changes before keeping or discarding them.
5. Inspect why `Fabric` has a large dirty tree before using it as an integration dependency.
6. Decide whether to install `hermes` and `fabric` commands into the `/mnt/develop` toolchain path.

