
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

Large local model/data storage:

```text
/mnt/develop/ollama-models/
/mnt/develop/Models/
/mnt/develop/datasets/
```

User-scoped tool/runtime storage:

```text
/mnt/develop/tools/go/
/mnt/develop/tools/ffmpeg-venv/
/mnt/develop/go/
/mnt/develop/build-cache/go/
```

These paths are allowed to be large. They are not Git source and should be backed up only when the model/data files or local tool runtimes are intentionally worth preserving.

## Known Large Paths

`cc-switch/src-tauri/target` can become very large. It was observed around 37G.

`/mnt/develop/ollama-models` is the preferred local model store for Ollama. It was empty when checked on 2026-05-12, but model pulls can grow quickly.

`/mnt/develop/tools/go` stores the user-scoped Go toolchain. `/mnt/develop/go` and `/mnt/develop/build-cache/go` store Go workspace/module/build cache data.

`/mnt/develop/tools/ffmpeg-venv` stores the user-scoped ffmpeg provider used when system `apt` installation is not available.

`cc-switch/src-tauri/target` is Rust/Tauri build output and should be treated as disposable cache.

To reclaim space later, from `cc-switch/src-tauri`:

```bash
cargo clean
```

Do not run cleanup commands while builds are active.

## Backup Guidance

Back up source, docs, configs, approved evidence/reports, and any local models or datasets you cannot easily re-pull.

Do not waste backup space on generated dependency/build caches unless you intentionally want fast restore.
