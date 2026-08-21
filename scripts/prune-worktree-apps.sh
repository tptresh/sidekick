#!/bin/bash
# prune-worktree-apps.sh - keep exactly one Sidekick.app on this Mac.
#
# Every checkout can run `make app`, and each bundle it produces carries the
# same CFBundleIdentifier. macOS resolves an app by that id, so a bundle left
# behind under .claude/worktrees can win the lookup and be launched instead of
# (or alongside) the build ship.sh just made - which is how two Sidekicks end
# up running at once.
#
# This deletes every app bundle outside the main checkout, drops it from the
# LaunchServices database, and re-registers the real one so the id resolves
# there. Build output only; nothing here is a source file. Safe to re-run.

set -u

COMMON_DIR=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
MAIN_ROOT=$(dirname "$COMMON_DIR")
APP_NAME=$(sed -n 's/^APP_NAME = //p' "$MAIN_ROOT/Makefile")
[ -n "$APP_NAME" ] || exit 0

LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
register() { [ -x "$LSREGISTER" ] && "$LSREGISTER" "$@" >/dev/null 2>&1; return 0; }

pruned=0
for stale in "$MAIN_ROOT"/.claude/worktrees/*/build/"$APP_NAME.app"; do
  [ -d "$stale" ] || continue
  # Anything running out of that bundle would survive the delete.
  pkill -f "^$stale/Contents/MacOS/" 2>/dev/null
  register -u "$stale"
  rm -rf "$stale"
  echo "pruned stale bundle: $stale"
  pruned=$((pruned + 1))
done

# Point the bundle id back at the real app whenever a rival was registered.
if [ "$pruned" -gt 0 ] && [ -d "$MAIN_ROOT/build/$APP_NAME.app" ]; then
  register -f "$MAIN_ROOT/build/$APP_NAME.app"
fi
exit 0
