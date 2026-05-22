---
name: finding-draft-from-evidence
description: Draft a structured security finding from offensive-research-portal evidence while leaving confirmation to the operator.
platforms: [linux, macos, windows]
category: security
metadata:
  workbench:
    sources:
      - pentest-ai-agents/.claude/agents/poc-validator.md
      - pentest-ai-agents/.claude/agents/report-generator.md
    action_class: advisory
    orp_required: true
    live_target_commands: false
---

# Finding Draft From Evidence

Use this skill after evidence has already been collected and stored through offensive-research-portal task events, scan output, generated reports, or operator notes.

## Purpose

Turn evidence into a draft finding that an operator can confirm, reject, or edit. This skill does not mark findings confirmed.

## Required Inputs

- Evidence excerpts or offensive-research-portal evidence IDs.
- Affected target/path/component.
- Observed behavior.
- Expected secure behavior.
- Scope context.
- Any reproduction notes already collected.

## Rules

1. Do not invent evidence.
2. Separate confirmed facts from inference.
3. If evidence is insufficient, produce an evidence gap list instead of a confident finding.
4. Keep reproduction steps non-destructive.
5. Do not claim exploitability beyond what the evidence proves.
6. Leave triage status as draft/unconfirmed.

## Output Format

```markdown
## Finding Draft

- Title:
- Severity: informational | low | medium | high | critical
- Confidence: low | medium | high
- Status: draft_unconfirmed
- Affected asset:
- Evidence references:

### Summary

### Impact

### Evidence

### Reproduction Steps

### Remediation

### Operator Review Checklist
- [ ] Evidence is sufficient
- [ ] Scope is valid
- [ ] Severity is correct
- [ ] Reproduction is safe and accurate
- [ ] PII/secrets reviewed
```

## offensive-research-portal Mapping

The output maps to a draft `findings` record and should not be treated as a confirmed report item until operator triage is complete.
