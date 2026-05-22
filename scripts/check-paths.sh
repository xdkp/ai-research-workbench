#!/usr/bin/env bash
set -u

ROOT="${AI_RESEARCH_ROOT:-/mnt/develop/AI_Research}"
status=0

ok() { printf 'PASS  %s\n' "$1"; }
warn() { printf 'WARN  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; status=1; }

printf 'AI Research path check\n'
printf 'Root: %s\n\n' "$ROOT"

if [ -d "$ROOT" ]; then ok "workspace root exists"; else fail "workspace root missing: $ROOT"; fi

for dir in Fabric cc-switch offensive-research-portal hermes-agent oh-my-claudecode .agents .codex; do
  if [ -d "$ROOT/$dir" ]; then
    ok "$dir exists"
  else
    warn "$dir missing"
  fi
done

printf '\nMounts\n'
if command -v findmnt >/dev/null 2>&1; then
  if findmnt /mnt/develop >/dev/null 2>&1; then
    ok "/mnt/develop is mounted"
    findmnt /mnt/develop -o TARGET,SOURCE,FSTYPE,OPTIONS --noheadings || true
  else
    warn "/mnt/develop is not mounted or not visible"
  fi
else
  warn "findmnt not available"
fi

printf '\nGit root state\n'
if [ -d "$ROOT/.git" ]; then
  if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ok "workspace root is a valid Git repo"
  else
    warn "workspace root has .git but is not a valid Git repo"
  fi
else
  ok "workspace root has no .git; child repos are separate"
fi

printf '\nChild repo state\n'
for repo in Fabric cc-switch offensive-research-portal hermes-agent oh-my-claudecode; do
  if [ -d "$ROOT/$repo/.git" ]; then
    ok "$repo has its own Git repo"
  elif [ -d "$ROOT/$repo" ]; then
    warn "$repo exists but has no .git"
  fi
done

exit "$status"
