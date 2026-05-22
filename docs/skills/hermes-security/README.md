# Hermes Security Skill Specs

Date: 2026-05-19

These are local workbench skill specifications extracted from `pentest-ai-agents` methodology for controlled Hermes use.

They are not installed into upstream `hermes-agent` yet. Treat them as the source specs for the first low-risk Hermes security skill slice.

## Ownership

| Area | Owner |
|---|---|
| Skill source specs | Root workbench docs |
| Execution runtime | Hermes |
| Provider/profile routing | cc-switch |
| Local model runtime | Ollama, optional |
| Scope, approval, evidence, findings, reports | offensive-research-portal |

## First Skill Slice

| Skill | Action Class | Live Target Commands | Purpose |
|---|---|---|---|
| `scope-guard-preflight` | advisory | No | Validate task context before any execution path. |
| `engagement-plan-from-scope` | advisory | No | Turn engagement scope into a phased task plan. |
| `passive-recon-summary` | passive_recon | No by default | Summarize passive source material and identify gaps. |
| `finding-draft-from-evidence` | advisory | No | Draft finding content from stored evidence. |
| `report-section-draft` | advisory | No | Draft report sections from approved offensive-research-portal records. |

## Installation Rule

Do not install or enable active testing skills until offensive-research-portal has action-class gating tests and UI/API approval paths for active tasks.

These specs intentionally avoid C2, phishing, payload crafting, credential testing, destructive testing, and privilege escalation workflows.
