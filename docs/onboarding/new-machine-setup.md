
# New Machine Setup

This is the blessed first-run path for the combined AI Research workspace.

## 1. Confirm Storage

Active development should happen on ext4:

```bash
findmnt /mnt/develop
df -hT /mnt/develop
```

Expected workspace:

```text
/mnt/develop/AI_Research
```

Optional convenience symlink:

```text
~/Develop -> /mnt/develop
```

## 2. Install System Tools

Minimum tools:

```text
git
curl
rg
node
pnpm
python3
uv
go
cargo
ffmpeg
gh
```

Optional tools:

```text
vercel      only for Vercel deploy/recovery work
docker      only for service containers later
ollama      only for local model hosting
```

Check current availability:

```bash
./scripts/check-tools.sh
```

## 3. Confirm Repos Exist

```bash
./scripts/check-paths.sh
```

Expected repos:

```text
Fabric
cc-switch
offensive-research-portal
hermes-agent
oh-my-claudecode
```

## 4. Install In This Order

Use each project’s own install docs. This workspace doc only defines the order.

1. `hermes-agent`
2. `Fabric`
3. `cc-switch`
4. `offensive-research-portal`
5. `oh-my-claudecode`, if using Claude Code customization

## 5. Configure Minimum Secrets

Do not create one giant workspace `.env`.

Use the owner-specific config locations:

- Hermes runtime secrets: Hermes config/env.
- Provider/profile secrets for coding CLIs: cc-switch where supported.
- Security workflow secrets: `offensive-research-portal` env/Vercel/Supabase/GitHub settings.
- Local assistant config: `.codex`, `.agents`, or tool-specific user config.

See:

```text
docs/stack-map/env-var-inventory.md
```

## 6. First Health Check

Run:

```bash
./scripts/doctor.sh
```

The doctor is read-only. It reports missing tools and likely setup gaps.

## 7. First Useful Workflow

A good first workflow is local-only:

1. Open `offensive-research-portal`.
2. Run root tests.
3. Build the report viewer.
4. Open Hermes CLI/TUI separately.
5. Use Fabric patterns manually for analysis/report text, but keep findings/evidence in `offensive-research-portal`.

Do not start with Vercel/Supabase/gateway unless the local stack is healthy.
