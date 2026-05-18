# Current Workspace Status

Date checked: 2026-05-12

Workspace root:

```text
/mnt/develop/AI_Research
```

This document records the current state of the combined AI Research Workbench so future changes do not have to rediscover the same layout, ownership, and risks.

## Implementation Phase

Current implementation status:

```text
P1 complete: workspace front door and docs exist
P2 complete: integration contracts exist
P3 complete: read-only health checks exist and pass
P4 in progress: Docker Compose covers csp-audit report viewer, scan worker, and Hermes gateway; heartbeat/task bridge processes are wired, but live agent API calls currently return 500 because the report viewer cannot reach Supabase before timeout
```

## Workspace Meta-Repo

The workspace root is now a valid Git repository.

Current committed baseline before local workflow proof update:

```text
46e7e1b Update workbench tool status
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

`csp-audit` is the system of record for this workflow. Hermes, Fabric, cc-switch, Ollama, Codex, and Claude Code are support tools around that control plane.

## Child Project Roles

| Project | Role | Ownership status |
| --- | --- | --- |
| `csp-audit` | Security control plane, scans, findings, approvals, report viewer, DAST gate | Active local development; local P4 bridge changes pending verification/commit |
| `hermes-agent` | Agent runtime, orchestration, skills, gateway, CLI/TUI/web surfaces | Upstream clone plus local Docker gateway integration files; do not push upstream casually |
| `Fabric` | Prompt/pattern library and analysis patterns | Upstream clone, keep clean |
| `cc-switch` | Claude Code / Codex style switching and local helper tooling | Clean child repo, has large Rust build cache |
| `Ollama` | Local model runtime and model storage | Client installed; daemon was not running when checked |
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
local P4 integration changes pending verification/commit
```

Current local P4 work:

```text
claim_next_agent_task RPC contract fixed to use p_agent_name
empty task queue now returns { task: null } consistently
agent claim route tests and Supabase claim helper tests added
Docker report-viewer image needs rebuild before running container uses these code changes
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

Vercel account/project work remains paused, but local tests/builds, report-viewer build, and control-plane hardening are committed or verified locally.

The first Compose slice for `csp-audit` lives at `docker-compose.yml` and currently includes the report viewer and scan worker. The Hermes gateway now has its own optional profile in the same file, seeds its runtime credentials into `hermes-home/.env`, and emits csp-audit heartbeats.

Latest local workflow proof, checked 2026-05-12:

```text
PASS  ./scripts/doctor.sh
PASS  hermes --help
PASS  fabric --version
PASS  go version
PASS  uv --version
PASS  ffmpeg -version
PASS  pnpm test
PASS  pnpm --prefix report-viewer lint
PASS  pnpm --prefix report-viewer exec vitest run
PASS  pnpm --prefix report-viewer exec tsc --noEmit
PASS  pnpm --prefix report-viewer build
PASS  python3 -m py_compile hermes-agent/scripts/csp-audit-heartbeat.py hermes-agent/scripts/csp-audit-task-runner.py
PASS  bash -n hermes-agent/scripts/gateway-bootstrap.sh
PASS  docker compose --env-file docker-compose.env --profile csp-audit --profile hermes-gateway config --quiet
PASS  docker compose ps shows csp-report-viewer, csp-scan-worker, and hermes-gateway running
PASS  report-viewer local HTTP probe: HTTP/1.1 200 OK at http://127.0.0.1:3000
PASS  csp-report-viewer and hermes-gateway images rebuilt after P4 bridge changes
WARN  live /api/agent/heartbeat returns 500: Supabase request timeout from inside the report-viewer container
WARN  receipt-mode task consumption remains blocked until Supabase connectivity/config is fixed
WARN  ollama daemon not reachable
FAIL  pnpm ops:validate due account/env prerequisites intentionally not configured
```

`pnpm ops:validate` failed on these expected local/deployment setup items:

```text
report-viewer/.vercel/project.json missing
REPORT_VIEWER_BASE_URL not set
SCAN_WORKER_TOKEN not set
AGENT_TOKEN warning/state check
```

Do not fix the Vercel-linked validation item until Vercel work is intentionally resumed. `SCAN_WORKER_TOKEN` is only needed when running a local scan worker or agent integration.

### `hermes-agent`

Current status:

```text
local Docker gateway integration files pending verification/commit
```

Current local P4 work:

```text
Dockerfile.gateway
gateway-bootstrap.sh
csp-audit-heartbeat.py
csp-audit-task-runner.py
```

Handling rule:

```text
Treat this as an upstream clone for upstream contribution purposes. The Docker gateway files are local workbench integration work and should not be pushed upstream unless a separate contribution decision is made.
```

### `Ollama`

Current tool state:

```text
client installed: 0.23.1
daemon status when checked: not reachable
preferred model path: /mnt/develop/ollama-models
```

Handling rule:

```text
Use Ollama as optional local inference runtime only. Do not store task state, evidence, findings, approvals, or reports in Ollama.
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
uv
go
cargo
ffmpeg
```

Useful tools currently found:

```text
gh
vercel
docker
ollama
hermes
fabric
```

Current user-scoped tool installs:

```text
uv      -> /home/m0bious/.local/bin/uv
go      -> /home/m0bious/.local/bin/go -> /mnt/develop/tools/go/bin/go
ffmpeg  -> /home/m0bious/.local/bin/ffmpeg -> /mnt/develop/tools/ffmpeg-venv managed binary
hermes  -> /home/m0bious/.local/bin/hermes, installed by uv tool from local hermes-agent clone
fabric  -> /home/m0bious/.local/bin/fabric, built from local Fabric clone
```

Current versions checked:

```text
uv 0.11.13
go version go1.26.3 linux/amd64
ffmpeg 7.0.2-static
fabric v1.4.452
hermes command available
```

Optional tools missing or not on `PATH`:

```text
none from the current workbench doctor list
```

Notes:

- `vercel` is installed. A new Vercel account exists, but the csp-audit report-viewer project still needs to be linked/configured to the new account.
- `ollama` is installed, but the local daemon was not reachable during the latest check.
- `go` caches are configured under `/mnt/develop/build-cache/go` so module/build cache growth stays on the ext4 development partition.

## Vercel Status

Vercel recovery is now active for the new account.

Current target:

```text
Supabase remains the same
Vercel project must be recreated or relinked under the new account
GitHub Actions remains the production deploy controller
REPORT_VIEWER_BASE_URL must be set as a GitHub Actions repository variable after first deploy
```

Do not enable duplicate Vercel Git production auto-deploys yet. Use GitHub Actions with `vercel pull`, `vercel build --prod`, and `vercel deploy --prebuilt --prod` first.

The repo can continue local development while the new Vercel project is being configured.

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
do not perform Vercel deploy actions until the new project is linked and secrets are configured
do not move Docker root data onto /mnt/develop yet
```

## Recommended Next Work

Recommended next sequence:

1. Link/configure the new Vercel project for `csp-audit/report-viewer` without enabling duplicate production auto-deploys.
2. Configure `SCAN_WORKER_TOKEN` only when starting local worker or Hermes task-claim integration.
3. Enable `CSP_AUDIT_TASK_POLL_ENABLED=true` only when intentionally testing gateway task consumption.
4. Use `docs/integrations/hermes-with-csp-audit.md` as the next implementation contract.
5. Prove one local approved-task style workflow before adding deployment services.
6. Start Ollama only when a local model task needs it.
7. Keep upstream clones clean unless an explicit upstream contribution branch is opened.

