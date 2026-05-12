#!/usr/bin/env bash
set -u

ROOT="${AI_RESEARCH_ROOT:-/mnt/develop/AI_Research}"
status=0

ok() { printf 'PASS  %s\n' "$1"; }
warn() { printf 'WARN  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; status=1; }

print_repo() {
  local name="$1"
  local path="$2"

  printf '\n== %s ==\n' "$name"
  printf 'Path: %s\n' "$path"

  if [ ! -d "$path/.git" ]; then
    fail "$name is not a Git repo"
    return
  fi

  local branch
  branch=$(git -C "$path" branch --show-current 2>/dev/null)
  if [ -z "$branch" ]; then
    branch="detached"
  fi

  local head
  head=$(git -C "$path" log -1 --format='%h %s' 2>/dev/null)

  local origin
  origin=$(git -C "$path" remote get-url origin 2>/dev/null)
  if [ -z "$origin" ]; then
    origin="none"
  fi

  local upstream
  upstream=$(git -C "$path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
  if [ -z "$upstream" ]; then
    upstream="none"
  fi

  local dirty_count
  dirty_count=$(git -C "$path" status --short 2>/dev/null | wc -l | tr -d ' ')

  printf 'Branch: %s\n' "$branch"
  printf 'HEAD: %s\n' "$head"
  printf 'Origin: %s\n' "$origin"
  printf 'Upstream tracking: %s\n' "$upstream"

  if [ "$dirty_count" = "0" ]; then
    ok "$name working tree clean"
  else
    warn "$name has $dirty_count changed/untracked entries"
  fi
}

printf 'AI Research repository manifest check\n'
printf 'Root: %s\n' "$ROOT"
printf 'Mode: read-only\n'

print_repo "AI Research Workbench" "$ROOT"
print_repo "Fabric" "$ROOT/Fabric"
print_repo "cc-switch" "$ROOT/cc-switch"
print_repo "csp-audit" "$ROOT/csp-audit"
print_repo "hermes-agent" "$ROOT/hermes-agent"
print_repo "oh-my-claudecode" "$ROOT/oh-my-claudecode"

exit "$status"

