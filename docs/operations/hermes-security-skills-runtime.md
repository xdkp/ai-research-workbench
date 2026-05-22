# Hermes Security Skills Runtime

Date: 2026-05-19

The first low-risk Hermes security skills are maintained in the root workbench at:

```text
docs/skills/hermes-security/
```

Docker Compose mounts them read-only into the Hermes gateway container at:

```text
/data/hermes/skills/security/workbench
```

This keeps the source of truth in the root meta-repo while making the specs visible to Hermes skill discovery.

## Why Read-Only

The skills are extracted from `pentest-ai-agents` methodology and intentionally reviewed before runtime use. The container should consume them, not rewrite them. Updates should happen through normal workbench commits.

## Active Skill Set

| Skill | Runtime Path | Action Class | Live Target Commands |
|---|---|---|---|
| `scope-guard-preflight` | `security/workbench/scope-guard-preflight` | advisory | No |
| `engagement-plan-from-scope` | `security/workbench/engagement-plan-from-scope` | advisory | No |
| `passive-recon-summary` | `security/workbench/passive-recon-summary` | passive_recon | No by default |
| `finding-draft-from-evidence` | `security/workbench/finding-draft-from-evidence` | advisory | No |
| `report-section-draft` | `security/workbench/report-section-draft` | advisory | No |

## Control Boundary

These skills can help Hermes reason, draft, and summarize. They do not replace offensive-research-portal controls.

Required control path:

```text
offensive-research-portal scope and task approval
-> Hermes skill-assisted execution or drafting
-> offensive-research-portal events/evidence/generated reports
-> operator triage
-> approved finding/report output
```

## Verification

Use the repeatable smoke check:

```bash
cd /mnt/develop/AI_Research
./scripts/prove-hermes-security-skills.sh
```

After changing this mount, verify Compose syntax:

```bash
cd /mnt/develop/AI_Research
docker compose config --quiet
```

If the gateway is already running, recreate it to pick up the mount:

```bash
docker compose --env-file docker-compose.env --profile hermes-gateway up -d --force-recreate hermes-gateway
```

Then inspect the mounted skill files:

```bash
docker compose exec hermes-gateway find /data/hermes/skills/security/workbench -name SKILL.md -maxdepth 3 -print
```

## Verified Locally

Checked on 2026-05-19:

```text
PASS docker compose config --quiet
PASS docker compose --env-file docker-compose.env --profile hermes-gateway up -d --force-recreate hermes-gateway
PASS docker compose exec hermes-gateway find /data/hermes/skills/security/workbench -maxdepth 3 -name SKILL.md -print
PASS /data/hermes/skills/security/workbench/scope-guard-preflight/SKILL.md is readable inside hermes-gateway
PASS hermes skills list --source local --enabled-only reports 5 local enabled security skills
```

Mounted skill files observed inside the container:

```text
/data/hermes/skills/security/workbench/engagement-plan-from-scope/SKILL.md
/data/hermes/skills/security/workbench/finding-draft-from-evidence/SKILL.md
/data/hermes/skills/security/workbench/passive-recon-summary/SKILL.md
/data/hermes/skills/security/workbench/report-section-draft/SKILL.md
/data/hermes/skills/security/workbench/scope-guard-preflight/SKILL.md
```
