
# Troubleshooting

## I Do Not Know Where To Start

Read:

```text
START_HERE.md
```

Then run:

```bash
./scripts/doctor.sh
```

## The Workspace Root Looks Like Git But Git Fails

Current audit found an empty `.git` directory at workspace root. Until intentionally fixed, treat child repos as separate Git repos.

Do not assume root-level docs are tracked by Git unless a valid root repo is created.

## Vercel Fails In CI

If Preview DAST secrets are missing, offensive-research-portal CI should skip Preview DAST cleanly.

If deploy or production DAST is intended, check:

```text
VERCEL_TOKEN
VERCEL_ORG_ID
VERCEL_PROJECT_ID
REPORT_VIEWER_BASE_URL repository variable
report-viewer root directory
```

## Findings Or Reports Are Confusing

Use `offensive-research-portal` as source of truth.

Hermes/Fabric output is draft material until confirmed/triaged in `offensive-research-portal`.

## Disk Space Is Disappearing

Check:

```bash
du -sh /mnt/develop/AI_Research/*
du -sh /mnt/develop/AI_Research/cc-switch/src-tauri/target
```

`cc-switch/src-tauri/target` is usually disposable build cache.
