
# Hermes With csp-audit

`csp-audit` already owns the security workflow spine:

```text
scope -> approved task -> execution evidence -> structured finding -> operator triage -> final report/export
```

Hermes should integrate as an executor and analysis assistant, not as a second control plane.

## Target Flow

```text
1. Operator creates/updates engagement scope in csp-audit.
2. Operator creates a task in csp-audit.
3. csp-audit validates target URL and scope.
4. Task is pending until approved, unless explicitly not_required.
5. Hermes claims an eligible task through csp-audit agent APIs.
6. Hermes executes only the allowed workflow.
7. Hermes posts task events, evidence, generated report material, and candidate finding data.
8. csp-audit stores structured findings and triage status.
9. Operator confirms, rejects, edits, or submits findings.
10. csp-audit exports/generates final report material from approved records.
```

## csp-audit Owns

- Engagements and scope.
- Task creation, status, and approval status.
- Agent task events.
- Evidence-bearing generated reports.
- Structured findings and triage status.
- Submissions, duplicates, exports, and final report output.

## Hermes Owns

- Agent execution loop.
- Tool use and reasoning during approved tasks.
- Memory and skill usage.
- Gateway/CLI/TUI interaction.
- Draft evidence summaries and candidate finding material.

## Integration Contract

Hermes must treat `csp-audit` task fields as binding:

```text
target_url
target_type
vuln_type
risk_level
allowed_actions
requires_approval
approval_status
engagement_id
reference_url
```

Hermes must not execute work for tasks that are not claimable by the csp-audit API.

Hermes should emit enough trace for review:

```text
task started
tool/action used
evidence found
candidate finding drafted
blocked or failed reason
completed summary
```

## Report Rule

Agent-generated text is draft material until the operator confirms it in `csp-audit`.

Final report content should come from approved/confirmed csp-audit records, not from Hermes memory alone.
