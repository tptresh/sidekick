# Spidey - working rules for Claude sessions

Spidey is a macOS launcher app (Swift + SwiftUI, SwiftPM, no dependencies).
It is developed and used by ONE person, locally, and mirrored to a public
GitHub repo at github.com/tptresh/sidekick. Several Claude sessions often
work on it concurrently in git worktrees. The whole
workflow below exists so concurrent sessions never leave work uncommitted,
unmerged, or unbuilt.

## Build & run

- `make build` - compile check; run it from anywhere, including a worktree
- `make app` - release build into `build/Sidekick.app` (the app is named
  Sidekick; the binary/repo is Spidey)
- `make test` - run the test suite (`swift test`)
- **`make app` only works in the main checkout.** Every bundle it produces
  carries the same bundle id, so a second one built in a worktree makes macOS
  run two Sidekicks at once. In a worktree use `make build` to check it
  compiles, and `scripts/ship.sh` to actually put your change in the running
  app. `make prune` cleans up bundles a worktree left behind.
- `make app` ad-hoc signs each build, so the Makefile resets the stale
  Accessibility grant; features needing Accessibility re-prompt after a
  rebuild. That is expected, not a bug.

## The ship workflow (solo trunk-based - no PRs of our own)

**When you finish a piece of work, run:**

```
scripts/ship.sh "one line describing the user-visible change"
```

That commits everything in your worktree, merges your branch into main,
rebuilds the app, relaunches it so the user is always testing the latest
build, records the insertion in `SHIPLOG.md`, pushes main to origin, and
fast-forwards your branch back level with main. Ship after each coherent chunk, not only at the very
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
- Never open a PR for your own work and never ask the user to review a
  merge - there is no reviewer on this side. Merging to main IS shipping.
- `ship.sh` pushes main to origin at the end, so never push by hand. Only
  main is public; never push a `claude/*` branch.
- Outside contributions arrive as pull requests from forks. Those are the
  user's to review and merge on GitHub, not something `ship.sh` touches. Use
  `gh pr view` / `gh pr diff` / `gh pr checkout` when asked to look at one.
- `main` is protected on GitHub: CI (`make build`, `make test`, the em dash
  check) must be green. If a push is rejected, fix the build, do not force.
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
  to keep the guard quiet). The same applies to the character written as a
  `\u{2014}` escape, which the guard also catches.
- Comment only non-obvious constraints (see the Makefile's tccutil note for
  the house style). Keep commit messages about user-visible behavior - they
  are what the shiplog points at.
- The project is open source (MIT). Keep code, names, and docs ordinary and
  readable. `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, and the workflows
  in `.github/` are public-facing: keep them accurate when behaviour changes,
  and hold them to the same no-em-dash rule as the UI.
