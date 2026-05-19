---
name: report-section-draft
description: Draft report sections from approved csp-audit findings and generated report material.
platforms: [linux, macos, windows]
category: security
metadata:
  workbench:
    sources:
      - pentest-ai-agents/.claude/agents/report-generator.md
      - pentest-ai-agents/.claude/agents/stig-analyst.md
      - pentest-ai-agents/.claude/agents/detection-engineer.md
    action_class: advisory
    csp_audit_required: true
    live_target_commands: false
---

# Report Section Draft

Use this skill to draft final-report sections from csp-audit records. It must not create new facts outside the approved evidence set.

## Purpose

Generate readable report material without forcing the operator to write everything manually.

## Allowed Inputs

- Approved csp-audit findings.
- Operator-confirmed evidence.
- Generated report material stored in csp-audit.
- Engagement metadata and scope.
- Remediation notes and defensive detections.

## Rules

1. Use approved findings and evidence only.
2. Do not include draft/unconfirmed findings in final language unless explicitly labeled.
3. Preserve severity and triage decisions from csp-audit.
4. Keep executive summaries non-alarmist and evidence-backed.
5. Separate remediation guidance from exploit narrative.
6. Redact secrets, tokens, and unnecessary personal data.

## Output Format

```markdown
## Report Section Draft

### Executive Summary

### Scope And Methodology

### Key Findings
| Severity | Finding | Affected Asset | Status |
|---|---|---|---|

### Finding Details

### Remediation Roadmap

### Defensive Detection Opportunities

### Appendix: Evidence Index
```

## csp-audit Mapping

The generated section should be stored as csp-audit generated report material and should link back to approved finding IDs.
