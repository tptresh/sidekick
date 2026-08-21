# SHIPLOG - ledger of every change shipped to main

Written only by `scripts/ship.sh` (never by hand). One entry per ship,
newest at the bottom. Statuses:

- **OK** - merged, built, app relaunched. The listed commits are live.
- **CONFLICT** - the merge was aborted; main was untouched. The entry says
  which branch still holds the work and how to resolve.
- **BROKEN** - the merge landed but `make app` failed; main does not build
  until a later OK entry. The running app is still the previous good build.

To trace a regression: read bottom-up, find the first ship after things
last worked, and inspect its listed commit hashes with `git show`.

## 2026-08-20 15:59 - OK - claude/spidey-local-dev-workflow-6bf8aa
- "Add auto-ship workflow: ship.sh, Stop/SessionStart hooks, SHIPLOG ledger, CLAUDE.md rules"
- merged commits:
  - 2e4e4ca Add auto-ship workflow: ship.sh, Stop/SessionStart hooks, SHIPLOG ledger, CLAUDE.md rules
- main is now at: bc1ba13 (build succeeded, app relaunched)

## 2026-08-20 16:32 - OK - claude/option-space-usage-ad5dac
- "Hotkey change takes effect on first press; app retries preferred hotkey when brought forward"
- merged commits:
  - 0a63575 Hotkey change takes effect on first press; app retries preferred hotkey when brought forward
- main is now at: 41c3348 (build succeeded, app relaunched)

## 2026-08-20 16:33 - OK - claude/hero-to-theme-06a73b
- "Preferences section renamed from Hero Theme to Theme"
- merged commits:
  - 14125cf Preferences section renamed from Hero Theme to Theme
- main is now at: 49b9c7d (build succeeded, app relaunched)

## 2026-08-20 16:33 - OK - claude/spidey-clipboard-auto-screenshots-ca3028
- "Screenshots auto-land in clipboard history: last 5 kept, type ss to grab and drag them into any app"
- merged commits:
  - 43c5837 Screenshots auto-land in clipboard history: last 5 kept, type ss to grab and drag them into any app
- main is now at: 5f32df2 (build succeeded, app relaunched)

## 2026-08-20 16:34 - OK - claude/process-timing-wording-f26921
- "Site-setup wording now says up to a few minutes instead of half a minute"
- merged commits:
  - 9b8b8c9 Site-setup wording now says up to a few minutes instead of half a minute
- main is now at: 90f504e (build succeeded, app relaunched)

## 2026-08-20 16:36 — OK — claude/spidey-clipboard-auto-screenshots-ca3028
- "Dragging a file/screenshot row out of the panel now works instead of moving the panel"
- merged commits:
  - 22ac3ac Dragging a file/screenshot row out of the panel now works instead of moving the panel
- main is now at: 10a068c (build succeeded, app relaunched)

## 2026-08-20 16:39 - OK - claude/spidey-remove-em-dashes-a87dec
- "No more em dashes anywhere in the app's text; ship now blocks any new ones from reaching the UI"
- merged commits:
  - 29107e2 No more em dashes anywhere in the app's text; ship now blocks any new ones from reaching the UI
- main is now at: 4896413 (build succeeded, app relaunched)

## 2026-08-20 16:48 - OK - claude/theme-change-animations-c6bdfd
- "Typing spidey or the bat now switches themes with a full screen entrance: the mask webslings in, the bat signal lights up"
- merged commits:
  - 11cf6fe Typing spidey or the bat now switches themes with a full screen entrance: the mask webslings in, the bat signal lights up
- main is now at: d0e6877 (build succeeded, app relaunched)

## 2026-08-20 16:49 - OK - claude/movie-search-visibility-311aed
- "Custom media sites now appear in searches immediately (via a Google site search) instead of staying hidden until a search page is verified"
- merged commits:
  - e059fcc Custom media sites now appear in searches immediately (via a Google site search) instead of staying hidden until a search page is verified
- main is now at: 8a1d415 (build succeeded, app relaunched)

## 2026-08-20 17:10 - CONFLICT - claude/movie-search-visibility-311aed
- merge into main conflicted and was aborted; main is untouched.
- unmerged commits:
  - 3d79d4e Custom sites' search is now learned by driving the site's real search box; results jump to the top matching title, never a dead Google page
- fix: in the worktree run 'git merge main', resolve the conflicts, commit, then re-run scripts/ship.sh

## 2026-08-20 17:11 - OK - claude/movie-search-visibility-311aed
- "Custom sites' search is now learned by driving the site's real search box; results jump to the top matching title, never a dead Google page"
- merged commits:
  - 19546f0 Merge main: keep demotion ranking, add learned-search open actions
  - 3d79d4e Custom sites' search is now learned by driving the site's real search box; results jump to the top matching title, never a dead Google page
- main is now at: 580c60f (build succeeded, app relaunched)

## 2026-08-20 17:17 - OK - claude/movie-search-visibility-311aed
- "Sites whose search could not be learned on the first try now retry automatically and on Check Now"
- merged commits:
  - adf4672 Sites whose search could not be learned on the first try now retry automatically and on Check Now
- main is now at: 18a6e58 (build succeeded, app relaunched)

## 2026-08-20 17:44 - OK - claude/movie-search-visibility-311aed
- "Search learning now rides out Cloudflare walls, learns title links straight from API responses, and runtime searches work on protected sites"
- merged commits:
  - bb96c60 Search learning now rides out Cloudflare walls, learns title links straight from API responses, and runtime searches work on protected sites
- main is now at: 328a62e (build succeeded, app relaunched)
