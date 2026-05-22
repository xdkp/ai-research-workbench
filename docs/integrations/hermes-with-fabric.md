
# Hermes With Fabric

Fabric is the reusable prompt-pattern library. Hermes is the executor and agent runtime.

## Purpose

Use Fabric patterns to improve analysis, summarization, triage, and report writing inside approved workflows.

Examples:

```text
analyze threat report
summarize evidence
improve finding writeup
write HackerOne-style report
review code
create security update
```

## Ownership Boundary

Fabric owns reusable prompt patterns.

Hermes may call, adapt, or wrap patterns into skills.

`offensive-research-portal` owns final security evidence and findings.

## Safe Usage Pattern

```text
raw evidence from offensive-research-portal/Hermes tools
→ Fabric pattern helps analyze or draft text
→ Hermes returns candidate material
→ offensive-research-portal stores structured finding/evidence
→ operator approves or edits
```

## Do Not

- Do not store final finding state in Fabric.
- Do not let Fabric pattern output bypass operator review.
- Do not treat a generated report draft as confirmed evidence.
