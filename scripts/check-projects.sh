#!/usr/bin/env bash
set -u

ROOT="${AI_RESEARCH_ROOT:-/mnt/develop/AI_Research}"
status=0
ok() { printf 'PASS  %s\n' "$1"; }
warn() { printf 'WARN  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; status=1; }

printf 'AI Research project check\n'
printf 'Root: %s\n\n' "$ROOT"

check_file() {
  local file="$1"
  local label="$2"
  if [ -f "$file" ]; then ok "$label"; else warn "$label missing"; fi
}

check_file "$ROOT/csp-audit/package.json" "csp-audit package.json"
check_file "$ROOT/csp-audit/report-viewer/package.json" "csp-audit report-viewer package.json"
check_file "$ROOT/csp-audit/supabase/schema.sql" "csp-audit Supabase schema"
check_file "$ROOT/hermes-agent/pyproject.toml" "hermes-agent pyproject.toml"
check_file "$ROOT/hermes-agent/uv.lock" "hermes-agent uv.lock"
check_file "$ROOT/Fabric/go.mod" "Fabric go.mod"
check_file "$ROOT/cc-switch/package.json" "cc-switch package.json"
check_file "$ROOT/cc-switch/src-tauri/Cargo.toml" "cc-switch Cargo.toml"
check_file "$ROOT/oh-my-claudecode/package.json" "oh-my-claudecode package.json"

printf '\nDirty state summary\n'
for repo in Fabric cc-switch csp-audit hermes-agent oh-my-claudecode; do
  if [ -d "$ROOT/$repo/.git" ]; then
    count=$(git -C "$ROOT/$repo" status --short 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" = "0" ]; then
      ok "$repo clean"
    else
      warn "$repo has $count changed/untracked entries"
    fi
  fi
done

printf '\nLarge cache hints\n'
if [ -d "$ROOT/cc-switch/src-tauri/target" ]; then
  du -sh "$ROOT/cc-switch/src-tauri/target" 2>/dev/null || true
  warn "cc-switch/src-tauri/target is disposable Rust build cache"
fi

exit "$status"
