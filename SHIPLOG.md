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

## 2026-08-20 17:55 - OK - claude/movie-search-visibility-311aed
- "Sites behind bot-protection walls are detected and open in Brave with the search copied to paste, instead of failing silently"
- merged commits:
  - 08352f8 Sites behind bot-protection walls are detected and open in Brave with the search copied to paste, instead of failing silently
- main is now at: c9a5a9a (build succeeded, app relaunched)

## 2026-08-20 18:04 - OK - claude/movie-search-visibility-311aed
- "Learned site searches are re-proved against the live site every check cycle; broken ones clear and relearn automatically"
- merged commits:
  - a08288f Learned site searches are re-proved against the live site every check cycle; broken ones clear and relearn automatically
- main is now at: 6787a9e (build succeeded, app relaunched)

## 2026-08-20 18:14 - OK - claude/spidey-setup-dependencies-10fe8f
- "Sidekick sets itself up at launch: requests all permissions up front, auto-installs blueutil and brightness via Homebrew, and shows setup status in Preferences"
- merged commits:
  - 2064d01 Sidekick sets itself up at launch: requests all permissions up front, auto-installs blueutil and brightness via Homebrew, and shows setup status in Preferences
- main is now at: f8c02f9 (build succeeded, app relaunched)

## 2026-08-20 18:20 - OK - claude/spidey-setup-dependencies-10fe8f
- "Automation permission prompts now actually appear at launch (the priming script sent no real Apple Event before)"
- merged commits:
  - 2b167b8 Automation permission prompts now actually appear at launch (the priming script sent no real Apple Event before)
- main is now at: 08ba61f (build succeeded, app relaunched)

## 2026-08-20 18:23 - OK - claude/jovial-benz-6dcb02
- "Contact search now recovers when a Contacts fetch fails after access is granted, instead of caching a false 'no matches' for 5 minutes"
- merged commits:
  - 26fc519 Contact search now recovers when a Contacts fetch fails after access is granted, instead of caching a false 'no matches' for 5 minutes
- main is now at: 8d50f2e (build succeeded, app relaunched)

## 2026-08-20 18:30 - OK - claude/jovial-benz-6dcb02
- "Typing a contact's name puts the person first with Message, Call, FaceTime, and Email actions that learn which one you use"
- merged commits:
  - a2d0bf5 Typing a contact's name puts the person first with Message, Call, FaceTime, and Email actions that learn which one you use
- main is now at: c327be6 (build succeeded, app relaunched)

## 2026-08-20 18:52 - OK - claude/duplicate-spidey-processes-40c37c
- "Only one Sidekick runs at a time: a launching copy retires older ones, and worktrees can no longer build rival app bundles"
- merged commits:
  - 6767fbe Only one Sidekick runs at a time: a launching copy retires older ones, and worktrees can no longer build rival app bundles
- main is now at: b107bc2 (build succeeded, app relaunched)

## 2026-08-20 19:10 - OK - claude/spidey-fullscreen-2d2826
- "Typing "full screen" now really puts the front window into macOS full screen (and back out again); "maximize" stays a plain screen-filling resize"
- merged commits:
  - 2c92d8b Typing "full screen" now really puts the front window into macOS full screen (and back out again); "maximize" stays a plain screen-filling resize
- main is now at: e4ba1bb (build succeeded, app relaunched)

## 2026-08-20 19:13 - OK - claude/spidey-fullscreen-2d2826
- "Typing "minimize" sends the front window to the Dock, and it works from full screen too"
- merged commits:
  - 936e050 Typing "minimize" sends the front window to the Dock, and it works from full screen too
- main is now at: 4284c45 (build succeeded, app relaunched)

## 2026-08-20 19:18 - OK - claude/sasuke-theme-replacement-74c118
- "Replace the Iron Man theme with Sasuke: a mini full-body figure in the menu bar, a light grey-lilac purple palette, and an entrance where his face appears and a giant Sharingan spins out of his eye"
- merged commits:
  - 95bc816 Replace the Iron Man theme with Sasuke: a mini full-body figure in the menu bar, a light grey-lilac purple palette, and an entrance where his face appears and a giant Sharingan spins out of his eye
- main is now at: a9a6ceb (build succeeded, app relaunched)

## 2026-08-20 19:20 - OK - claude/spidey-contact-access-8ee1c4
- "Typing a first name like claire now brings up her contact options - Message, Call, FaceTime, Email, her photo and card - plus call/message/email/facetime verbs and a full card view with addresses, sites and birthday"
- merged commits:
  - 6974201 Typing a first name like claire now brings up her contact options - Message, Call, FaceTime, Email, her photo and card - plus call/message/email/facetime verbs and a full card view with addresses, sites and birthday
- main is now at: 64508a2 (build succeeded, app relaunched)

## 2026-08-20 19:21 - OK - claude/system-tasks-performance-14f2a8
- "Spidey understands spoken system commands: set a timer for 5 minutes, turn off wifi, what's my ip, dim the screen"
- merged commits:
  - 894e943 Spidey understands spoken system commands: set a timer for 5 minutes, turn off wifi, what's my ip, dim the screen
- main is now at: bda7915 (build succeeded, app relaunched)

## 2026-08-20 19:57 - OK - claude/sasuke-theme-replacement-74c118
- "Redraw Sasuke from reference: a bold chibi figure in the menu bar with his swept spiky hair and lit eyes, and a proper chibi bust in the entrance with the Sharingan and Rinnegan in his eyes"
- merged commits:
  - 19d2192 Redraw Sasuke from reference: a bold chibi figure in the menu bar with his swept spiky hair and lit eyes, and a proper chibi bust in the entrance with the Sharingan and Rinnegan in his eyes
- main is now at: 9bd0a13 (build succeeded, app relaunched)

## 2026-08-20 21:57 - OK - claude/sasuke-theme-replacement-74c118
- "Sasuke theme now uses his Rinnegan as the menu bar emblem, and the entrance is an anime-styled drawing of his face with Rinnegan opening all over the screen"
- merged commits:
  - 9f74fa6 Sasuke theme now uses his Rinnegan as the menu bar emblem, and the entrance is an anime-styled drawing of his face with Rinnegan opening all over the screen
- main is now at: b066b3d (build succeeded, app relaunched)

## 2026-08-20 22:01 - OK - claude/sasuke-theme-replacement-74c118
- "Preferences can point the Sasuke entrance at a real picture of him, which the animation uses instead of the drawn face"
- merged commits:
  - 11c758f Preferences can point the Sasuke entrance at a real picture of him, which the animation uses instead of the drawn face
- main is now at: 64262e6 (build succeeded, app relaunched)

## 2026-08-20 22:12 - OK - claude/sasuke-theme-replacement-74c118
- "Sasuke's entrance now uses the real anime render of him: he arrives, gathers purple chakra, and Rinnegan open across the screen as chakra rings roll out"
- merged commits:
  - 7f78dd4 Sasuke's entrance now uses the real anime render of him: he arrives, gathers purple chakra, and Rinnegan open across the screen as chakra rings roll out
- main is now at: 9ee24d0 (build succeeded, app relaunched)

## 2026-08-20 22:29 - OK - claude/search-result-ordering-5adac3
- "Searching the web now ranks above the guessed homepage, so a query with no obvious site leads with the search instead of an address that may not exist"
- merged commits:
  - 4a13791 Searching the web now ranks above the guessed homepage, so a query with no obvious site leads with the search instead of an address that may not exist
- main is now at: 481ecd0 (build succeeded, app relaunched)

## 2026-08-20 22:31 - OK - claude/google-brave-icon-664463
- "The web search row now shows the Brave icon instead of Google's, matching the browser it opens in"
- merged commits:
  - 134dbf9 The web search row now shows the Brave icon instead of Google's, matching the browser it opens in
- main is now at: 0714ec9 (build succeeded, app relaunched)

## 2026-08-20 22:32 - OK - claude/sasuke-theme-replacement-74c118
- "Sasuke's entrance is now the anime close-up of his Rinnegan filling the screen, with the tomoe turning in his eye, chakra rolling out of it and more Rinnegan opening around the edges"
- merged commits:
  - c1c3334 Sasuke's entrance is now the anime close-up of his Rinnegan filling the screen, with the tomoe turning in his eye, chakra rolling out of it and more Rinnegan opening around the edges
- main is now at: d114eb7 (build succeeded, app relaunched)

## 2026-08-20 22:36 - OK - claude/sasuke-theme-replacement-74c118
- "Keep the tomoe in Sasuke's eye their proper comma shape while it spins, instead of stretching them as they come round"
- merged commits:
  - 99d548c Keep the tomoe in Sasuke's eye their proper comma shape while it spins, instead of stretching them as they come round
- main is now at: 6c295ed (build succeeded, app relaunched)

## 2026-08-20 22:41 - OK - claude/sasuke-theme-icon-f6eb90
- "Show the actual purple Rinnegan next to the search field in the Sasuke theme, instead of the flat menu-bar badge"
- merged commits:
  - 91c2d53 Show the actual purple Rinnegan next to the search field in the Sasuke theme, instead of the flat menu-bar badge
- main is now at: 75655f0 (build succeeded, app relaunched)

## 2026-08-20 22:43 - CONFLICT - claude/last-watched-episode-memory-c418cb
- merge into main conflicted and was aborted; main is untouched.
- unmerged commits:
  - beebd8b Spidey remembers where you got to in a show: watching the pitt s1e6 saves it, an open episode page or the Mac going to sleep saves it by itself, and typing the show name offers Resume and Next up
- fix: in the worktree run 'git merge main', resolve the conflicts, commit, then re-run scripts/ship.sh

## 2026-08-20 22:44 - OK - claude/last-watched-episode-memory-c418cb
- "Spidey remembers where you got to in a show: watching the pitt s1e6 saves it, an open episode page or the Mac going to sleep saves it by itself, and typing the show name offers Resume and Next up"
- merged commits:
  - 3d0513c Merge main into last-watched-episode-memory
  - beebd8b Spidey remembers where you got to in a show: watching the pitt s1e6 saves it, an open episode page or the Mac going to sleep saves it by itself, and typing the show name offers Resume and Next up
- main is now at: db719ad (build succeeded, app relaunched)

## 2026-08-20 22:49 - OK - claude/sasuke-theme-icon-f6eb90
- "Sasuke's search field now reads Awaken the Rinnegan, matching the eye beside it"
- merged commits:
  - cacab6c Sasuke's search field now reads Awaken the Rinnegan, matching the eye beside it
- main is now at: 6d4aa46 (build succeeded, app relaunched)
