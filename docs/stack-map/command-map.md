
# Command Map

Run commands from the listed directory unless noted.

| Goal | Command | Directory | Notes |
|---|---|---|---|
| Check workspace paths | `./scripts/check-paths.sh` | `AI_Research` | Read-only |
| Check tools | `./scripts/check-tools.sh` | `AI_Research` | Read-only |
| Workspace doctor | `./scripts/doctor.sh` | `AI_Research` | Read-only summary |
| Hermes health | `hermes doctor` | any | Requires Hermes installed |
| Start Hermes | `hermes` | any | CLI/TUI entry |
| Start Hermes gateway | `hermes gateway` | any | Optional messaging layer |
| Fabric help | `fabric --help` | any | Requires Fabric installed |
| csp-audit tests | `pnpm test` | `csp-audit` | No Vercel required |
| csp-audit setup validation | `pnpm ops:validate` | `csp-audit` | Read-only setup validation |
| report-viewer lint | `pnpm --prefix report-viewer lint` | `csp-audit` | No Vercel required |
| report-viewer tests | `pnpm --prefix report-viewer exec vitest run` | `csp-audit` | No Vercel required |
| report-viewer build | `pnpm --prefix report-viewer build` | `csp-audit` | No Vercel account required |
| cc-switch typecheck | `pnpm typecheck` | `cc-switch` | Desktop project check |
| cc-switch unit tests | `pnpm test:unit` | `cc-switch` | If deps installed |
| GitHub auth check | `gh auth status` | any | External auth check |
| Vercel CLI check | `vercel --version` | any | Only needed for Vercel work |
| Ollama CLI check | `ollama --version` | any | Confirms client is installed |
| Ollama daemon check | `ollama list` | any | Confirms local daemon is reachable |

## Local-First Rule

Prefer local checks first:

```text
pnpm test
lint
typecheck
build
```

Only use Vercel/Supabase/GitHub account workflows when the local project is healthy and the task requires those services.
