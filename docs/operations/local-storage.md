
# Local Storage Policy

Active development lives on:

```text
/mnt/develop/AI_Research
```

This is the ext4 build workspace.

## Source vs Cache

Source:

```text
Fabric/
cc-switch/
csp-audit/
hermes-agent/
oh-my-claudecode/
docs/
scripts/
```

Disposable caches/build outputs:

```text
node_modules/
.next/
dist/
build/
coverage/
cc-switch/src-tauri/target/
.pytest_cache/
.ruff_cache/
```

## Known Large Path

`cc-switch/src-tauri/target` can become very large. It was observed around 37G.

It is Rust/Tauri build output and should be treated as disposable cache.

To reclaim space later, from `cc-switch/src-tauri`:

```bash
cargo clean
```

Do not run cleanup commands while builds are active.

## Backup Guidance

Back up source, docs, configs, and approved evidence/reports.

Do not waste backup space on generated dependency/build caches unless you intentionally want fast restore.
