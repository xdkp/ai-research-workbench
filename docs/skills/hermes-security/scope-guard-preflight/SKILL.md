---
name: scope-guard-preflight
description: Preflight safety and scope validation checklist for Hermes security tasks before any execution path begins.
platforms: [linux, macos, windows]
category: security
metadata:
  workbench:
    source: pentest-ai-agents/.claude/agents/_scope-guard.md
    action_class: advisory
    orp_required: true
    live_target_commands: false
---

# Scope Guard Preflight

Use this skill before Hermes accepts, plans, or executes any security task.

## Purpose

Confirm that the task has enough authorized context to proceed and that Hermes is not relying on prompt text alone for safety.

`offensive-research-portal` remains authoritative for target validation, engagement scope, approval state, task events, evidence, findings, and reports.

## Required Inputs

- offensive-research-portal task ID, if already created.
- Engagement ID or scope block.
- Target URL, domain, repository, or artifact identifier.
- Requested action class:
  - `advisory`
  - `passive_recon`
  - `active_non_destructive`
  - `exploit_capable`
  - `restricted`
- Operator approval status from offensive-research-portal.
- Evidence/output destination.

## Decision Rules

1. If there is no scope context, stop and request scope.
2. If the target is not represented in offensive-research-portal scope, stop.
3. If the target matches out-of-scope rules, stop.
4. If the task requires active target interaction and approval is not granted, stop.
5. If the task asks for destructive behavior, denial of service, phishing, C2, persistence, credential abuse, or payload crafting, classify it as `restricted` and stop unless a separate written authorization path exists.
6. If the task only drafts, summarizes, or plans from stored data, continue as `advisory`.
7. If the task uses only passive source material, continue as `passive_recon` only when scope is clear.

## Output Format

Return a compact preflight result:

```markdown
## Scope Guard Result

- Decision: proceed | blocked | needs_operator_approval
- Action class: advisory | passive_recon | active_non_destructive | exploit_capable | restricted
- Target: <target>
- Engagement: <engagement id or name>
- Approval status: <status>
- Reason: <one or two sentences>
- Required next step: <next action>
```

## Hard Boundary

This skill does not execute commands. It only decides whether the next workflow may proceed.
