# SHIPLOG — ledger of every change shipped to main

Written only by `scripts/ship.sh` (never by hand). One entry per ship,
newest at the bottom. Statuses:

- **OK** — merged, built, app relaunched. The listed commits are live.
- **CONFLICT** — the merge was aborted; main was untouched. The entry says
  which branch still holds the work and how to resolve.
- **BROKEN** — the merge landed but `make app` failed; main does not build
  until a later OK entry. The running app is still the previous good build.

To trace a regression: read bottom-up, find the first ship after things
last worked, and inspect its listed commit hashes with `git show`.

## 2026-08-20 15:59 — OK — claude/spidey-local-dev-workflow-6bf8aa
- "Add auto-ship workflow: ship.sh, Stop/SessionStart hooks, SHIPLOG ledger, CLAUDE.md rules"
- merged commits:
  - 2e4e4ca Add auto-ship workflow: ship.sh, Stop/SessionStart hooks, SHIPLOG ledger, CLAUDE.md rules
- main is now at: bc1ba13 (build succeeded, app relaunched)

## 2026-08-20 16:32 — OK — claude/option-space-usage-ad5dac
- "Hotkey change takes effect on first press; app retries preferred hotkey when brought forward"
- merged commits:
  - 0a63575 Hotkey change takes effect on first press; app retries preferred hotkey when brought forward
- main is now at: 41c3348 (build succeeded, app relaunched)
