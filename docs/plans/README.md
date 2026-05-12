# Workbench Planning Archive

This directory preserves historical planning records for the local AI Research Workbench.

These documents are local workspace records. They are not upstream `hermes-agent`, `Fabric`, `cc-switch`, or `oh-my-claudecode` documentation, and they should not be committed into those upstream clones unless a separate upstream contribution is intentionally prepared.

## Archived Plans

| Document | Purpose |
| --- | --- |
| `2026-05-11-project-structure-and-docs-cleanup.md` | Original onboarding and structure cleanup plan for combining Hermes, Fabric, cc-switch, csp-audit, and local assistant config. |
| `2026-05-11-ai-research-workbench-deep-audit.md` | Deep audit of the combined workspace, gaps, best-practice operating model, and 30-day roadmap. |

## Implemented Operational Docs

The active workbench docs live here:

```text
docs/onboarding/
docs/stack-map/
docs/integrations/
docs/operations/
```

`csp-audit` remains the security system of record for scope, tasks, evidence, findings, approvals, generated report material, and final report output. Hermes, Fabric, cc-switch, Codex, and Claude Code support that workflow.
