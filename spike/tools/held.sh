#!/bin/bash
# Usage: spike/tools/held.sh <command...>
# Runs <command> while holding, in the documented order: the machine-wide `studio` lock, one slot of the
# heavy pool, and the worktree's own atomic .locks/studio directory (09 section 2.5, rule 4).
TOOLS=/Users/bogdan/RobloxProjects/tools
WT="$(cd "$(dirname "$0")/../.." && pwd)"
if [ "${1:-}" = "--inner" ]; then
  shift
  mkdir -p "$WT/.locks"
  mkdir "$WT/.locks/studio" || { echo "worktree .locks/studio is held"; exit 75; }
  trap 'rmdir "$WT/.locks/studio"' EXIT
  "$@"
  exit $?
fi
exec "$TOOLS/with-lock.sh" studio --owner gulp-spike --game Gulp --timeout 1200 -- \
  "$TOOLS/with-heavy.sh" --owner gulp-spike --game Gulp --timeout 900 -- "$0" --inner "$@"
