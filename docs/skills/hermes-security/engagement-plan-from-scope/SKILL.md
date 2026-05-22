---
name: engagement-plan-from-scope
description: Create a safe phased security engagement plan from offensive-research-portal scope and rules of engagement.
platforms: [linux, macos, windows]
category: security
metadata:
  workbench:
    sources:
      - pentest-ai-agents/.claude/agents/engagement-planner.md
      - pentest-ai-agents/.claude/agents/threat-modeler.md
    action_class: advisory
    orp_required: true
    live_target_commands: false
---

# Engagement Plan From Scope

Use this skill to turn offensive-research-portal engagement scope into an operator-reviewable workflow plan.

## Purpose

Produce a structured plan that can become offensive-research-portal tasks. This skill does not create findings, run commands, or bypass approval.

## Required Inputs

- Engagement name and ID.
- In-scope targets.
- Out-of-scope targets.
- Allowed and forbidden techniques.
- Time window, rate limits, and communication rules if available.
- Testing type: web, API, infrastructure, cloud, source review, or mixed.

## Planning Rules

1. Ask for missing scope or rules of engagement before producing executable task steps.
2. Keep the plan phased and reviewable.
3. Mark every active step with its required action class.
4. Keep destructive, social engineering, C2, persistence, credential attacks, and denial-of-service steps out of the default plan.
5. Prefer low-risk validation and evidence capture paths.
6. Do not create tasks directly unless the calling workflow is explicitly authorized to call offensive-research-portal task APIs.

## Output Format

```markdown
## Engagement Plan

### Scope Summary
- In scope:
- Out of scope:
- Assumptions:

### Risk Controls
- Approval required for:
- Explicitly excluded:
- Evidence handling:

### Proposed Task Plan
| Order | Task | Action Class | Target | Expected Evidence | Approval Required |
|---|---|---|---|---|---|

### Open Questions
1.
```

## offensive-research-portal Mapping

Each proposed task should map cleanly to a offensive-research-portal `agent_tasks` record with explicit `target_url`, `requires_approval`, `approval_status`, and evidence expectations.
