#!/bin/bash
# sync-hook.sh — Claude Code "SessionStart" hook.
#
# When a session starts (or resumes) in a worktree whose branch has fallen
# behind main, fast-forward it so new work always starts from the latest
# shipped code. Only touches a clean tree; never rewrites anything
# (--ff-only cannot lose or merge changes — it either advances or does nothing).

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
cat >/dev/null

git rev-parse --git-dir >/dev/null 2>&1 || exit 0
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
[ "$BRANCH" = "main" ] && exit 0
[ -n "$(git status --porcelain 2>/dev/null)" ] && exit 0

git merge --ff-only -q main 2>/dev/null || true
exit 0
