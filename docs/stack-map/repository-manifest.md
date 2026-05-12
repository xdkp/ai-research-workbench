# Repository Manifest

Date checked: 2026-05-12

This workspace intentionally uses a meta-repo plus separate child repositories.

The root repo tracks the shared workbench layer. The child repos keep their own upstream history, remotes, branches, and dirty state.

## Why This Exists

The child projects are not tracked as normal folders in the root repo because that would mix unrelated histories and make it easy to accidentally commit huge caches or upstream source trees.

The manifest gives the workspace a stable map without forcing a monorepo migration.

## Root Meta-Repo

| Field | Value |
| --- | --- |
| Path | `/mnt/develop/AI_Research` |
| Purpose | Shared onboarding, integration docs, and health scripts |
| Branch | `master` |
| Current commit | `62127f2 Add repository manifest and repo health check` |
| Origin | `https://github.com/xdkp/ai-research-workbench.git` |
| Tracks child source code | No |

The root `.gitignore` excludes child repos:

```text
Fabric/
cc-switch/
csp-audit/
hermes-agent/
oh-my-claudecode/
```

## Child Repositories

| Repo | Branch | Current commit | Primary remote | Current state |
| --- | --- | --- | --- | --- |
| `Fabric` | `main` | `6a9b55a0 chore(release): Update version to v1.4.452` | `https://github.com/danielmiessler/Fabric.git` | Clean |
| `cc-switch` | `main` | `1af92d7b fix(clippy): resolve all 12 clippy 1.95 warnings to pass CI` | `https://github.com/xdkp/cc-switch-custom.git` | Clean |
| `csp-audit` | `develop` | `2a1d7b3 Harden task controls and update Next security patch` | `https://github.com/xdkp/csp-audit.git` | Clean |
| `hermes-agent` | `main` | `ebf2ea584 feat(terminal,cli): docker_extra_args + display.timestamps` | `https://github.com/NousResearch/hermes-agent.git` | Clean |
| `oh-my-claudecode` | `main` | `0ac52cda Merge main back into dev for release sync` | `https://github.com/Yeachan-Heo/oh-my-claudecode.git` | Clean |

## Additional Remotes

`cc-switch` has an upstream remote:

```text
upstream https://github.com/farion1231/cc-switch.git
```

Use `origin` for personal/fork work and `upstream` only for syncing with the original project.

## Current Handling Rules

### Root Meta-Repo

Safe to commit:

```text
README.md
START_HERE.md
docs/
scripts/
.gitignore
```

Do not force the child repositories into the root repo.

Planning archive: `docs/plans/README.md`.

### `csp-audit`

This is the active product/control plane. Continue development here for:

```text
engagement scope
task approval
evidence
findings
report generation
DAST gate
operator review
```

Do not reset current changes.

### `hermes-agent`

Use as orchestration/runtime support. Do not store local workbench planning docs inside this upstream clone.

Workbench planning records live in `docs/plans/` at the root meta-repo.

### `Fabric`

Current state is clean. Keep it clean unless a deliberate upstream contribution branch is opened.

### `cc-switch`

Clean repo with large local Rust build output under:

```text
cc-switch/src-tauri/target
```

Clean only when storage pressure requires it:

```bash
cd /mnt/develop/AI_Research/cc-switch/src-tauri
cargo clean
```

### `oh-my-claudecode`

Clean reference/config repo. Use for Claude Code setup patterns.

## How To Refresh This Map

Run:

```bash
./scripts/check-repos.sh
```

This script is read-only. It does not fetch, pull, push, clean, reset, or print secrets.

## Future Options

Current mode:

```text
meta-repo docs/scripts + independent child repos
```

Possible future modes:

```text
Git submodules
Git subtree
true monorepo
Docker Compose service workspace
```

Do not move to those until the workflow and ownership boundaries are stable.

