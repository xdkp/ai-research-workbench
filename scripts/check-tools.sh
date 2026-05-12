#!/usr/bin/env bash
set -u

status=0
ok() { printf 'PASS  %s\n' "$1"; }
warn() { printf 'WARN  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; status=1; }
check_required() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    ok "$name: $(command -v "$name")"
  else
    fail "$name missing"
  fi
}
check_optional() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    ok "$name: $(command -v "$name")"
  else
    warn "$name missing (optional)"
  fi
}

printf 'AI Research tool check\n\n'

for tool in git rg node pnpm python3; do
  check_required "$tool"
done

for tool in uv go cargo ffmpeg gh vercel docker ollama hermes fabric; do
  check_optional "$tool"
done

printf '\nVersions\n'
for cmd in 'node --version' 'pnpm --version' 'python3 --version' 'git --version' 'go version' 'cargo --version' 'gh --version' 'vercel --version' 'docker --version'; do
  printf '$ %s\n' "$cmd"
  $cmd 2>/dev/null | head -2 || true
done

exit "$status"
