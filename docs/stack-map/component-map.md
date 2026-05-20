
# Component Map

| Component | Role | Stack | Entry Point | Config Owner | Required For |
|---|---|---|---|---|---|
| `csp-audit` | Security workflow system of record | Node, Next.js, Supabase SQL | `pnpm test`, `report-viewer` | csp-audit env/Vercel/Supabase | Scope, tasks, evidence, findings, reports |
| `hermes-agent` | Agent runtime and executor | Python, Node extras | `hermes`, `hermes gateway` | Hermes config/env | Agent CLI/TUI, gateway, skills, memory |
| `Fabric` | Prompt-pattern library | Go, Markdown patterns | `fabric` | Fabric config | Reusable analysis/writing prompts |
| `cc-switch` | Provider/profile switchboard | Tauri, TypeScript, Rust | desktop app / Tauri | cc-switch profile DB/config | Model/provider routing for coding CLIs |
| `Ollama` | Local model runtime | Go service / local HTTP API | `ollama serve`, `ollama list` | Ollama env/service config | Optional local inference for Hermes/Fabric/Codex-compatible flows |
| `oh-my-claudecode` | Claude Code support/customization | Node/TypeScript | project scripts | local Claude Code config | Claude Code workflow customization |
| `pentest-ai-agents` | Pentest methodology and role prompt reference | Markdown, Claude-agent prompts | reference only | workbench extraction docs | Hermes security skill source material |
| `.codex` | Codex local config | local metadata | Codex | local-only | Codex behavior and workspace context |
| `.agents` | Agent workspace metadata | local metadata | local agents | local-only | Agent workspace context |

## System Of Record

For security work, `csp-audit` owns final state:

```text
engagements -> tasks -> events/evidence -> findings -> triage -> reports/submissions
```

Other tools can generate ideas, analysis, commands, draft text, and evidence material. Ollama can host local models for those tools. `pentest-ai-agents` can provide methodology and skill source material. None of them should become the authoritative finding store.
