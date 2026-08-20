# Spidey - working rules for Claude sessions

Spidey is a macOS launcher app (Swift + SwiftUI, SwiftPM, no dependencies).
It is developed and used by ONE person, locally, with no git remote. Several
Claude sessions often work on it concurrently in git worktrees. The whole
workflow below exists so concurrent sessions never leave work uncommitted,
unmerged, or unbuilt.

## Build & run

- `make app` - release build into `build/Sidekick.app` (the app is named
  Sidekick; the binary/repo is Spidey)
- `make test` - run the test suite (`swift test`)
- `make app` ad-hoc signs each build, so the Makefile resets the stale
  Accessibility grant; features needing Accessibility re-prompt after a
  rebuild. That is expected, not a bug.

## The ship workflow (solo trunk-based - no PRs, no pushes, no remote)

**When you finish a piece of work, run:**

```
scripts/ship.sh "one line describing the user-visible change"
```

That commits everything in your worktree, merges your branch into main,
rebuilds the app, relaunches it so the user is always testing the latest
build, records the insertion in `SHIPLOG.md`, and fast-forwards your branch
back level with main. Ship after each coherent chunk, not only at the very
end - small merges conflict less.

Safety nets (configured in `.claude/settings.json`):
- A **Stop hook** auto-runs ship whenever a session pauses with unshipped
  work, so nothing is ever stranded. If the ship fails, the failure text is
  fed back into the session - **you must fix it** (resolve the conflict or
  the compile error, then re-run `scripts/ship.sh`).
- A **SessionStart hook** fast-forwards a stale worktree to main, so you
  start from the latest shipped code. If your branch has diverged instead,
  run `git merge main` yourself before doing anything else.

Rules:
- Never create PRs, never push, never ask the user to review a merge -
  there is no remote and no reviewer. Merging to main IS shipping.
- Never edit `SHIPLOG.md` by hand; only `scripts/ship.sh` writes it.
- If `make app` fails, main is marked BROKEN in the shiplog - fixing it
  takes priority over any other task.

## When something regresses ("this used to work")

`SHIPLOG.md` is the ledger: one entry per ship, newest at the bottom, each
with the merged commit hashes and the resulting main commit. To find which
insertion broke things:

1. Read `SHIPLOG.md` bottom-up to shortlist suspect ships.
2. Inspect a suspect directly: `git show <hash>` / `git log -p -- <file>`.
3. For a hard case, `git bisect start <bad-main-hash> <good-main-hash>`
   with `make app` + a manual check at each step.
4. Undo a bad ship with `git revert -m 1 <merge-hash>` on a worktree
   branch, then `scripts/ship.sh "revert <what it broke>"`. Prefer a real
   fix; revert when the user is blocked from testing.

## Code conventions

- **No em dashes (U+2014) in anything the user can see.** UI strings, labels,
  help text, tooltips, error messages: use a plain hyphen or rewrite the
  sentence instead. `ship.sh` refuses to ship if one appears anywhere under
  `Sources/`, so just never type one there (comments included - simplest way
  to keep the guard quiet).
- Comment only non-obvious constraints (see the Makefile's tccutil note for
  the house style). Keep commit messages about user-visible behavior - they
  are what the shiplog points at.
- The project will eventually be open-sourced: keep code, names, and docs
  ordinary and readable, but do not add licensing/CI/contribution scaffolding
  until asked.
