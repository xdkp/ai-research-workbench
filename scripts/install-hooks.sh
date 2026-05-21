#!/bin/sh
set -e
TEMPLATE="$(pwd)/docs/git-hooks/pre-push.template"
if [ ! -f "$TEMPLATE" ]; then
  echo "Template not found: $TEMPLATE" >&2
  exit 1
fi
find . -type d -name ".git" | while read -r GITDIR; do
  HOOKDIR="$GITDIR/hooks"
  if [ -d "$HOOKDIR" ]; then
    cp "$TEMPLATE" "$HOOKDIR/pre-push"
    chmod +x "$HOOKDIR/pre-push" || true
    echo "Updated $HOOKDIR/pre-push"
  fi
done
