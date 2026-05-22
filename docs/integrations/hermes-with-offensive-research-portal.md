
# Hermes With offensive-research-portal

`offensive-research-portal` already owns the security workflow spine:

```text
scope -> approved task -> execution evidence -> structured finding -> operator triage -> final report/export
```

Hermes should integrate as an executor and analysis assistant, not as a second control plane.

## Target Flow

```text
1. Operator creates/updates engagement scope in offensive-research-portal.
2. Operator creates a task in offensive-research-portal.
3. offensive-research-portal validates target URL and scope.
4. Task is pending until approved, unless explicitly not_required.
5. Hermes claims an eligible task through offensive-research-portal agent APIs.
6. Hermes executes only the allowed workflow.
7. Hermes posts task events, evidence, generated report material, and candidate finding data.
8. offensive-research-portal stores structured findings and triage status.
9. Operator confirms, rejects, edits, or submits findings.
10. offensive-research-portal exports/generates final report material from approved records.
```

## offensive-research-portal Owns

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

Hermes must treat `offensive-research-portal` task fields as binding:

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

Hermes must not execute work for tasks that are not claimable by the offensive-research-portal API.

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

Agent-generated text is draft material until the operator confirms it in `offensive-research-portal`.

Final report content should come from approved/confirmed offensive-research-portal records, not from Hermes memory alone.

## First Local Proof Workflow

Before wiring a long-running Hermes worker, prove the local stack in this order:

```text
1. Run the workbench doctor.
2. Run offensive-research-portal tests and report-viewer checks.
3. Start report-viewer locally at http://127.0.0.1:3000.
4. Create or inspect a scoped offensive-research-portal task locally.
5. Use Hermes/Fabric only to draft analysis or report material.
6. Save approved evidence, findings, and final report material back in offensive-research-portal.
```

Current local proof result, checked 2026-05-12:

```text
PASS  doctor and toolchain checks
PASS  offensive-research-portal tests
PASS  report-viewer lint, vitest, and build
PASS  local report-viewer HTTP probe
WARN  ops:validate still expects Vercel/env setup that is intentionally paused
```

Do not use Hermes memory, Fabric output, or local notes as the final report source. They are draft inputs. `offensive-research-portal` remains the durable record for task state, evidence, findings, approvals, and report output.
