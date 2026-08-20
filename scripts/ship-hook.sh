#!/bin/bash
# ship-hook.sh - Claude Code "Stop" hook.
#
# Fires whenever a Claude session finishes a turn. If the session left
# uncommitted or unmerged work behind, this runs scripts/ship.sh so the
# change lands on main, gets built, and the app relaunches - automatically.
#
# Exit 0  = nothing to do, or ship succeeded.
# Exit 2  = ship failed (merge conflict or broken build); stderr is fed back
#           to the Claude session so it fixes the problem instead of stopping.

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
cat >/dev/null # drain the hook's stdin JSON; we decide from git state instead

git rev-parse --git-dir >/dev/null 2>&1 || exit 0
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0

DIRTY=0
[ -n "$(git status --porcelain 2>/dev/null)" ] && DIRTY=1
AHEAD=0
if [ "$BRANCH" != "main" ]; then
  AHEAD=$(git rev-list --count main.."$BRANCH" 2>/dev/null || echo 0)
fi
[ "$DIRTY" -eq 0 ] && [ "$AHEAD" -eq 0 ] && exit 0

# Don't hammer a known-failing state: if the last ship attempt failed at
# exactly this commit with a clean tree, there is nothing new to try.
MARKER="$(git rev-parse --path-format=absolute --git-common-dir)/ship-failed-at"
STATE="$BRANCH $(git rev-parse HEAD)"
if [ "$DIRTY" -eq 0 ] && [ -f "$MARKER" ] && [ "$(cat "$MARKER")" = "$STATE" ]; then
  exit 0
fi

OUT=$(scripts/ship.sh "auto-ship: session stopped with unshipped changes" 2>&1)
if [ $? -ne 0 ]; then
  echo "$BRANCH $(git rev-parse HEAD)" >"$MARKER"
  echo "AUTO-SHIP FAILED - Spidey's main branch is not cleanly built. You must fix this now (see SHIPLOG.md for the record). Details:
$OUT" >&2
  exit 2
fi
rm -f "$MARKER" 2>/dev/null
exit 0
