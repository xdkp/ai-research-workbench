#!/usr/bin/env bash
set -u

ROOT="${AI_RESEARCH_ROOT:-/mnt/develop/AI_Research}"
status=0

printf 'AI Research workspace doctor\n'
printf 'Root: %s\n' "$ROOT"
printf 'Date: %s\n\n' "$(date -Iseconds 2>/dev/null || date)"

run_check() {
  local label="$1"
  local script="$2"
  printf '\n== %s ==\n' "$label"
  if [ -x "$script" ]; then
    "$script" || status=1
  elif [ -f "$script" ]; then
    bash "$script" || status=1
  else
    printf 'FAIL  missing script: %s\n' "$script"
    status=1
  fi
}

run_check "Paths" "$ROOT/scripts/check-paths.sh"
run_check "Tools" "$ROOT/scripts/check-tools.sh"
run_check "Projects" "$ROOT/scripts/check-projects.sh"

printf '\n== Recommended next docs ==\n'
printf '%s\n' \
  'START_HERE.md' \
  'docs/onboarding/new-machine-setup.md' \
  'docs/stack-map/component-map.md' \
  'docs/stack-map/config-ownership.md' \
  'docs/integrations/hermes-with-csp-audit.md'

exit "$status"
