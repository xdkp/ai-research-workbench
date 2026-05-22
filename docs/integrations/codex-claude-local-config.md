
# Codex And Claude Local Config

This workspace contains local assistant metadata under:

```text
.agents/
.codex/
oh-my-claudecode/
```

These are local workflow helpers, not the security finding source of truth.

## Role

Use local assistant config for:

- coding behavior
- repo-specific instructions
- local workflow shortcuts
- skill/plugin metadata
- editor/assistant integration

Do not use it for:

- final vulnerability findings
- report approval state
- authoritative evidence records
- production secrets inventory

Those belong in `offensive-research-portal` and/or external secret stores.

## Sync Policy

Before syncing local config across machines, check for:

```text
API keys
tokens
private paths
account IDs
local-only mount paths
personal preference files
```

Keep secrets out of Git.
