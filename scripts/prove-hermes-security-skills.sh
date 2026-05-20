#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SERVICE="hermes-gateway"
RUNTIME_DIR="/data/hermes/skills/security/workbench"
EXPECTED_SKILLS=(
  engagement-plan-from-scope
  finding-draft-from-evidence
  passive-recon-summary
  report-section-draft
  scope-guard-preflight
)

printf 'Hermes security skills smoke check\n'
printf 'Root: %s\n\n' "$ROOT"

printf '== Compose syntax ==\n'
docker compose config --quiet
printf 'PASS docker compose config --quiet\n\n'

printf '== Container status ==\n'
docker compose ps "$SERVICE"
printf '\n'

printf '== Mounted SKILL.md files ==\n'
mounted="$(docker compose exec -T "$SERVICE" find "$RUNTIME_DIR" -maxdepth 3 -name SKILL.md -print | sort)"
printf '%s\n' "$mounted"

for skill in "${EXPECTED_SKILLS[@]}"; do
  expected_path="$RUNTIME_DIR/$skill/SKILL.md"
  if ! grep -Fqx "$expected_path" <<< "$mounted"; then
    printf 'FAIL missing mounted skill: %s\n' "$expected_path" >&2
    exit 1
  fi
done
printf 'PASS all expected SKILL.md files are mounted\n\n'

printf '== Hermes local enabled skills ==\n'
list_output="$(docker compose exec -T "$SERVICE" hermes skills list --source local --enabled-only)"
printf '%s\n' "$list_output"

for skill in "${EXPECTED_SKILLS[@]}"; do
  if ! grep -Fq "$skill" <<< "$list_output"; then
    printf 'FAIL Hermes did not list local enabled skill: %s\n' "$skill" >&2
    exit 1
  fi
done
if ! grep -Fq '5 local' <<< "$list_output"; then
  printf 'FAIL Hermes local skill count did not report 5 local skills\n' >&2
  exit 1
fi
printf '\nPASS Hermes discovered all five local security skills\n'
