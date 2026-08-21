#!/bin/bash
# ship.sh - make the current change live, in one step.
#
# Spidey is a solo local project: no remotes, no PRs. "Shipping" means:
#   1. commit whatever changed in this checkout (worktree or main)
#   2. merge the branch into main
#   3. rebuild the app from main (make app)
#   4. relaunch the app so testing always uses the latest build
#   5. append a traceable entry to SHIPLOG.md (the ledger of every insertion)
#
# Usage: scripts/ship.sh "short description of the change"
# Run it from anywhere inside the repo or any worktree. Safe to run
# concurrently from several sessions - a lock serializes ships.
#
# Exit code 0 = main is up to date, built, and running.
# Exit code 1 = something failed; stderr says what and SHIPLOG.md records it.

set -u

MSG="${1:-auto-ship}"

WT_ROOT=$(git rev-parse --show-toplevel) || exit 1
COMMON_DIR=$(git rev-parse --path-format=absolute --git-common-dir)
MAIN_ROOT=$(dirname "$COMMON_DIR")
SHIPLOG="$MAIN_ROOT/SHIPLOG.md"
LOCK="$COMMON_DIR/ship.lock"

# ---- lock: only one ship at a time (a build can take a while) ----
waited=0
until mkdir "$LOCK" 2>/dev/null; do
  sleep 5
  waited=$((waited + 5))
  if [ "$waited" -ge 600 ]; then
    echo "ship: gave up after 10min waiting for another ship to finish (stale lock? rmdir $LOCK)" >&2
    exit 1
  fi
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

STAMP=$(date '+%Y-%m-%d %H:%M')
BRANCH=$(git -C "$WT_ROOT" rev-parse --abbrev-ref HEAD)

# Append an entry to SHIPLOG.md and commit it on main.
# $1 = status word (OK / CONFLICT / BROKEN), $2 = detail lines (already formatted)
log_entry() {
  {
    echo ""
    echo "## $STAMP - $1 - $BRANCH"
    printf '%s\n' "$2"
  } >>"$SHIPLOG"
  git -C "$MAIN_ROOT" add SHIPLOG.md
  git -C "$MAIN_ROOT" commit -q -m "shiplog: $1 from $BRANCH" 2>/dev/null || true
}

# ---- 0. house rule: the app's UI must never show an em dash ----
# Every user-visible string lives under Sources/, so that is what we scan.
# The character is built with printf so this script never contains one itself.
EMDASH=$(printf '\342\200\224')
if git -C "$WT_ROOT" grep -nI --untracked -e "$EMDASH" -- Sources >&2; then
  echo "ship: em dash (U+2014) found under Sources/ (listed above). The UI must never show one (see CLAUDE.md) - use a plain hyphen or rewrite, then re-run scripts/ship.sh." >&2
  exit 1
fi
# The same character written as a Swift escape reads straight past the grep
# above, and reaches the UI just the same. EpisodeParser is the one legitimate
# use: it strips separators, em dash included, out of show titles.
if git -C "$WT_ROOT" grep -nI --untracked -e 'u{2014}' -- Sources ':!Sources/Spidey/Services/EpisodeParser.swift' >&2; then
  echo "ship: em dash written as a \\u{2014} escape found under Sources/ (listed above) - use a plain hyphen or rewrite, then re-run scripts/ship.sh." >&2
  exit 1
fi

# ---- 1. commit everything in the current checkout ----
if [ -n "$(git -C "$WT_ROOT" status --porcelain)" ]; then
  git -C "$WT_ROOT" add -A
  git -C "$WT_ROOT" commit -q -m "$MSG"
fi

# ---- 2. merge into main (skipped when already on main) ----
MERGED_COMMITS=""
if [ "$BRANCH" != "main" ]; then
  # Stray manual edits in the main checkout must not block the merge - keep them.
  if [ -n "$(git -C "$MAIN_ROOT" status --porcelain)" ]; then
    git -C "$MAIN_ROOT" add -A
    git -C "$MAIN_ROOT" commit -q -m "Manual edits found on main (auto-committed by ship)"
  fi
  AHEAD=$(git -C "$MAIN_ROOT" rev-list --count main.."$BRANCH" 2>/dev/null || echo 0)
  if [ "$AHEAD" -gt 0 ]; then
    MERGED_COMMITS=$(git -C "$MAIN_ROOT" log --oneline main.."$BRANCH" | sed 's/^/  - /')
    if ! git -C "$MAIN_ROOT" merge --no-ff -q "$BRANCH" -m "Merge $BRANCH: $MSG" >/dev/null 2>&1; then
      git -C "$MAIN_ROOT" merge --abort 2>/dev/null
      log_entry "CONFLICT" "- merge into main conflicted and was aborted; main is untouched.
- unmerged commits:
$MERGED_COMMITS
- fix: in the worktree run 'git merge main', resolve the conflicts, commit, then re-run scripts/ship.sh"
    echo "ship: merging $BRANCH into main hit a conflict. main was left untouched.
To fix: run 'git merge main' inside the worktree, resolve the conflicting files, commit, then re-run scripts/ship.sh." >&2
      exit 1
    fi
  fi
fi

# ---- 3. build the app from main ----
BUILD_LOG=$(mktemp)
if ! make -C "$MAIN_ROOT" app >"$BUILD_LOG" 2>&1; then
  ERRTAIL=$(tail -40 "$BUILD_LOG")
  FIRST_ERR=$(grep -m1 'error:' "$BUILD_LOG" || echo "(no 'error:' line; see stderr)")
  log_entry "BROKEN" "- merged, but 'make app' FAILED - main is at $(git -C "$MAIN_ROOT" rev-parse --short HEAD) and does not build.
- merged commits:
${MERGED_COMMITS:-  - (none, rebuild of existing main)}
- first error: $FIRST_ERR
- fix the build and re-run scripts/ship.sh (the running app is still the previous good build)"
  echo "ship: the merge landed on main but the build FAILED. Fix the compile error, then re-run scripts/ship.sh.
Build output (tail):
$ERRTAIL" >&2
  rm -f "$BUILD_LOG"
  exit 1
fi
rm -f "$BUILD_LOG"

# ---- 4. relaunch so the running app is always the latest build ----
APP_NAME=$(sed -n 's/^APP_NAME = //p' "$MAIN_ROOT/Makefile")

# App bundles left behind in worktrees carry this one's bundle id, so macOS can
# resolve the app to a stale copy and run it beside the build we just made.
"$MAIN_ROOT/scripts/prune-worktree-apps.sh" >/dev/null 2>&1

RELAUNCHED="launched"
if pgrep -xq "$APP_NAME"; then
  pkill -x "$APP_NAME"
  # Wait for it to actually exit. Opening the new build while the old one still
  # holds the status item and the global hot key is how two copies end up
  # running, so a fixed sleep is not good enough.
  for _ in $(seq 20); do
    pgrep -xq "$APP_NAME" || break
    sleep 0.25
  done
  pkill -9 -x "$APP_NAME" 2>/dev/null
  RELAUNCHED="relaunched"
fi
open "$MAIN_ROOT/build/$APP_NAME.app"

# ---- 5. record the insertion in the ledger ----
log_entry "OK" "- \"$MSG\"
- merged commits:
${MERGED_COMMITS:-  - (none - rebuild/relaunch only)}
- main is now at: $(git -C "$MAIN_ROOT" rev-parse --short HEAD) (build succeeded, app $RELAUNCHED)"

# ---- keep the worktree branch level with main so future merges stay small ----
if [ "$BRANCH" != "main" ]; then
  git -C "$WT_ROOT" merge --ff-only -q main 2>/dev/null || true
fi

echo "ship: OK - $BRANCH merged, app rebuilt and $RELAUNCHED, SHIPLOG updated (main @ $(git -C "$MAIN_ROOT" rev-parse --short HEAD))"
exit 0
