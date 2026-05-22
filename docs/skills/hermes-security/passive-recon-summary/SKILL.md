---
name: passive-recon-summary
description: Summarize passive reconnaissance material and identify safe follow-up questions without running live target commands.
platforms: [linux, macos, windows]
category: security
metadata:
  workbench:
    sources:
      - pentest-ai-agents/.claude/agents/osint-collector.md
      - pentest-ai-agents/.claude/agents/recon-advisor.md
    action_class: passive_recon
    orp_required: true
    live_target_commands: false
---

# Passive Recon Summary

Use this skill to analyze passive source material already provided by the operator, offensive-research-portal, or approved tooling output.

## Purpose

Create a concise recon summary and recommend safe next questions. This skill must not run DNS, HTTP, port scan, crawler, fuzzing, or vulnerability scan commands by itself.

## Allowed Inputs

- User-provided URLs, screenshots, headers, scan outputs, crawl outputs, or notes.
- offensive-research-portal scan reports and route inventories.
- Public documentation text pasted into the task.
- Passive OSINT notes already collected by approved tools.

## Rules

1. Do not interact with live targets from this skill.
2. Clearly label facts, evidence-backed observations, and hypotheses.
3. Do not infer authorization beyond the provided scope.
4. Recommend active checks only as candidate offensive-research-portal tasks with the required action class.
5. Preserve uncertainty when evidence is incomplete.

## Output Format

```markdown
## Passive Recon Summary

### Confirmed Observations
- [evidence] Observation

### Hypotheses
- [hypothesis] Statement and why it might matter

### Candidate Follow-Up Tasks
| Task | Target | Action Class | Why | Approval Required |
|---|---|---|---|---|

### Evidence Gaps
- Missing item
```
