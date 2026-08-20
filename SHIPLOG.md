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

## 2026-08-20 16:33 — OK — claude/hero-to-theme-06a73b
- "Preferences section renamed from Hero Theme to Theme"
- merged commits:
  - 14125cf Preferences section renamed from Hero Theme to Theme
- main is now at: 49b9c7d (build succeeded, app relaunched)

## 2026-08-20 16:33 — OK — claude/spidey-clipboard-auto-screenshots-ca3028
- "Screenshots auto-land in clipboard history: last 5 kept, type ss to grab and drag them into any app"
- merged commits:
  - 43c5837 Screenshots auto-land in clipboard history: last 5 kept, type ss to grab and drag them into any app
- main is now at: 5f32df2 (build succeeded, app relaunched)

## 2026-08-20 16:34 — OK — claude/process-timing-wording-f26921
- "Site-setup wording now says up to a few minutes instead of half a minute"
- merged commits:
  - 9b8b8c9 Site-setup wording now says up to a few minutes instead of half a minute
- main is now at: 90f504e (build succeeded, app relaunched)
