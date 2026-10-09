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
  - c110ac8 Add auto-ship workflow: ship.sh, Stop/SessionStart hooks, SHIPLOG ledger, CLAUDE.md rules
- main is now at: 100c384 (build succeeded, app relaunched)

## 2026-08-20 16:32 - OK - claude/option-space-usage-ad5dac
- "Hotkey change takes effect on first press; app retries preferred hotkey when brought forward"
- merged commits:
  - 37081dc Hotkey change takes effect on first press; app retries preferred hotkey when brought forward
- main is now at: b24b587 (build succeeded, app relaunched)

## 2026-08-20 16:33 - OK - claude/hero-to-theme-06a73b
- "Preferences section renamed from Hero Theme to Theme"
- merged commits:
  - 9bc3aa1 Preferences section renamed from Hero Theme to Theme
- main is now at: b173b9c (build succeeded, app relaunched)

## 2026-08-20 16:33 - OK - claude/spidey-clipboard-auto-screenshots-ca3028
- "Screenshots auto-land in clipboard history: last 5 kept, type ss to grab and drag them into any app"
- merged commits:
  - ff1ac55 Screenshots auto-land in clipboard history: last 5 kept, type ss to grab and drag them into any app
- main is now at: 25ffb87 (build succeeded, app relaunched)

## 2026-08-20 16:34 - OK - claude/process-timing-wording-f26921
- "Site-setup wording now says up to a few minutes instead of half a minute"
- merged commits:
  - e9beaa4 Site-setup wording now says up to a few minutes instead of half a minute
- main is now at: b0d29c8 (build succeeded, app relaunched)

## 2026-08-20 16:36 — OK — claude/spidey-clipboard-auto-screenshots-ca3028
- "Dragging a file/screenshot row out of the panel now works instead of moving the panel"
- merged commits:
  - 10725cc Dragging a file/screenshot row out of the panel now works instead of moving the panel
- main is now at: 48f58a7 (build succeeded, app relaunched)

## 2026-08-20 16:39 - OK - claude/spidey-remove-em-dashes-a87dec
- "No more em dashes anywhere in the app's text; ship now blocks any new ones from reaching the UI"
- merged commits:
  - 0d5ed00 No more em dashes anywhere in the app's text; ship now blocks any new ones from reaching the UI
- main is now at: a81c35f (build succeeded, app relaunched)

## 2026-08-20 16:48 - OK - claude/theme-change-animations-c6bdfd
- "Typing spidey or the bat now switches themes with a full screen entrance: the mask webslings in, the bat signal lights up"
- merged commits:
  - 54f2dfd Typing spidey or the bat now switches themes with a full screen entrance: the mask webslings in, the bat signal lights up
- main is now at: 4f74028 (build succeeded, app relaunched)

## 2026-08-20 16:49 - OK - claude/movie-search-visibility-311aed
- "Custom media sites now appear in searches immediately (via a Google site search) instead of staying hidden until a search page is verified"
- merged commits:
  - 0e21e21 Custom media sites now appear in searches immediately (via a Google site search) instead of staying hidden until a search page is verified
- main is now at: 627561c (build succeeded, app relaunched)

## 2026-08-20 17:10 - CONFLICT - claude/movie-search-visibility-311aed
- merge into main conflicted and was aborted; main is untouched.
- unmerged commits:
  - 505f57c Custom sites' search is now learned by driving the site's real search box; results jump to the top matching title, never a dead Google page
- fix: in the worktree run 'git merge main', resolve the conflicts, commit, then re-run scripts/ship.sh

## 2026-08-20 17:11 - OK - claude/movie-search-visibility-311aed
- "Custom sites' search is now learned by driving the site's real search box; results jump to the top matching title, never a dead Google page"
- merged commits:
  - da89850 Merge main: keep demotion ranking, add learned-search open actions
  - 505f57c Custom sites' search is now learned by driving the site's real search box; results jump to the top matching title, never a dead Google page
- main is now at: f437262 (build succeeded, app relaunched)

## 2026-08-20 17:17 - OK - claude/movie-search-visibility-311aed
- "Sites whose search could not be learned on the first try now retry automatically and on Check Now"
- merged commits:
  - 3f45fbb Sites whose search could not be learned on the first try now retry automatically and on Check Now
- main is now at: 0a13be3 (build succeeded, app relaunched)

## 2026-08-20 17:44 - OK - claude/movie-search-visibility-311aed
- "Search learning now rides out Cloudflare walls, learns title links straight from API responses, and runtime searches work on protected sites"
- merged commits:
  - 7874abc Search learning now rides out Cloudflare walls, learns title links straight from API responses, and runtime searches work on protected sites
- main is now at: 657d960 (build succeeded, app relaunched)

## 2026-08-20 17:55 - OK - claude/movie-search-visibility-311aed
- "Sites behind bot-protection walls are detected and open in Brave with the search copied to paste, instead of failing silently"
- merged commits:
  - 1e2b633 Sites behind bot-protection walls are detected and open in Brave with the search copied to paste, instead of failing silently
- main is now at: 414e8a6 (build succeeded, app relaunched)

## 2026-08-20 18:04 - OK - claude/movie-search-visibility-311aed
- "Learned site searches are re-proved against the live site every check cycle; broken ones clear and relearn automatically"
- merged commits:
  - f35f9c9 Learned site searches are re-proved against the live site every check cycle; broken ones clear and relearn automatically
- main is now at: afceeb5 (build succeeded, app relaunched)

## 2026-08-20 18:14 - OK - claude/spidey-setup-dependencies-10fe8f
- "Sidekick sets itself up at launch: requests all permissions up front, auto-installs blueutil and brightness via Homebrew, and shows setup status in Preferences"
- merged commits:
  - 0e1c591 Sidekick sets itself up at launch: requests all permissions up front, auto-installs blueutil and brightness via Homebrew, and shows setup status in Preferences
- main is now at: 707f591 (build succeeded, app relaunched)

## 2026-08-20 18:20 - OK - claude/spidey-setup-dependencies-10fe8f
- "Automation permission prompts now actually appear at launch (the priming script sent no real Apple Event before)"
- merged commits:
  - bf1e424 Automation permission prompts now actually appear at launch (the priming script sent no real Apple Event before)
- main is now at: a203f36 (build succeeded, app relaunched)

## 2026-08-20 18:23 - OK - claude/jovial-benz-6dcb02
- "Contact search now recovers when a Contacts fetch fails after access is granted, instead of caching a false 'no matches' for 5 minutes"
- merged commits:
  - 71f9ca0 Contact search now recovers when a Contacts fetch fails after access is granted, instead of caching a false 'no matches' for 5 minutes
- main is now at: e37e2c5 (build succeeded, app relaunched)

## 2026-08-20 18:30 - OK - claude/jovial-benz-6dcb02
- "Typing a contact's name puts the person first with Message, Call, FaceTime, and Email actions that learn which one you use"
- merged commits:
  - 98c7422 Typing a contact's name puts the person first with Message, Call, FaceTime, and Email actions that learn which one you use
- main is now at: 725883b (build succeeded, app relaunched)

## 2026-08-20 18:52 - OK - claude/duplicate-spidey-processes-40c37c
- "Only one Sidekick runs at a time: a launching copy retires older ones, and worktrees can no longer build rival app bundles"
- merged commits:
  - 7119f68 Only one Sidekick runs at a time: a launching copy retires older ones, and worktrees can no longer build rival app bundles
- main is now at: 9900a56 (build succeeded, app relaunched)

## 2026-08-20 19:10 - OK - claude/spidey-fullscreen-2d2826
- "Typing "full screen" now really puts the front window into macOS full screen (and back out again); "maximize" stays a plain screen-filling resize"
- merged commits:
  - 026f31f Typing "full screen" now really puts the front window into macOS full screen (and back out again); "maximize" stays a plain screen-filling resize
- main is now at: eee4ec8 (build succeeded, app relaunched)

## 2026-08-20 19:13 - OK - claude/spidey-fullscreen-2d2826
- "Typing "minimize" sends the front window to the Dock, and it works from full screen too"
- merged commits:
  - 7461b71 Typing "minimize" sends the front window to the Dock, and it works from full screen too
- main is now at: 6431096 (build succeeded, app relaunched)

## 2026-08-20 19:18 - OK - claude/sasuke-theme-replacement-74c118
- "Replace the Iron Man theme with Sasuke: a mini full-body figure in the menu bar, a light grey-lilac purple palette, and an entrance where his face appears and a giant Sharingan spins out of his eye"
- merged commits:
  - 4832bda Replace the Iron Man theme with Sasuke: a mini full-body figure in the menu bar, a light grey-lilac purple palette, and an entrance where his face appears and a giant Sharingan spins out of his eye
- main is now at: 33b4cd3 (build succeeded, app relaunched)

## 2026-08-20 19:20 - OK - claude/spidey-contact-access-8ee1c4
- "Typing a first name like claire now brings up her contact options - Message, Call, FaceTime, Email, her photo and card - plus call/message/email/facetime verbs and a full card view with addresses, sites and birthday"
- merged commits:
  - 98e5365 Typing a first name like claire now brings up her contact options - Message, Call, FaceTime, Email, her photo and card - plus call/message/email/facetime verbs and a full card view with addresses, sites and birthday
- main is now at: d58c1d4 (build succeeded, app relaunched)

## 2026-08-20 19:21 - OK - claude/system-tasks-performance-14f2a8
- "Spidey understands spoken system commands: set a timer for 5 minutes, turn off wifi, what's my ip, dim the screen"
- merged commits:
  - 8270773 Spidey understands spoken system commands: set a timer for 5 minutes, turn off wifi, what's my ip, dim the screen
- main is now at: f07326b (build succeeded, app relaunched)

## 2026-08-20 19:57 - OK - claude/sasuke-theme-replacement-74c118
- "Redraw Sasuke from reference: a bold chibi figure in the menu bar with his swept spiky hair and lit eyes, and a proper chibi bust in the entrance with the Sharingan and Rinnegan in his eyes"
- merged commits:
  - 5d51d81 Redraw Sasuke from reference: a bold chibi figure in the menu bar with his swept spiky hair and lit eyes, and a proper chibi bust in the entrance with the Sharingan and Rinnegan in his eyes
- main is now at: 8a189e8 (build succeeded, app relaunched)

## 2026-08-20 21:57 - OK - claude/sasuke-theme-replacement-74c118
- "Sasuke theme now uses his Rinnegan as the menu bar emblem, and the entrance is an anime-styled drawing of his face with Rinnegan opening all over the screen"
- merged commits:
  - 8e08f25 Sasuke theme now uses his Rinnegan as the menu bar emblem, and the entrance is an anime-styled drawing of his face with Rinnegan opening all over the screen
- main is now at: e3e9794 (build succeeded, app relaunched)

## 2026-08-20 22:01 - OK - claude/sasuke-theme-replacement-74c118
- "Preferences can point the Sasuke entrance at a real picture of him, which the animation uses instead of the drawn face"
- merged commits:
  - d201e54 Preferences can point the Sasuke entrance at a real picture of him, which the animation uses instead of the drawn face
- main is now at: 702706b (build succeeded, app relaunched)

## 2026-08-20 22:12 - OK - claude/sasuke-theme-replacement-74c118
- "Sasuke's entrance now uses the real anime render of him: he arrives, gathers purple chakra, and Rinnegan open across the screen as chakra rings roll out"
- merged commits:
  - 6e8d954 Sasuke's entrance now uses the real anime render of him: he arrives, gathers purple chakra, and Rinnegan open across the screen as chakra rings roll out
- main is now at: 0596b42 (build succeeded, app relaunched)

## 2026-08-20 22:29 - OK - claude/search-result-ordering-5adac3
- "Searching the web now ranks above the guessed homepage, so a query with no obvious site leads with the search instead of an address that may not exist"
- merged commits:
  - 81e9f4e Searching the web now ranks above the guessed homepage, so a query with no obvious site leads with the search instead of an address that may not exist
- main is now at: 6fc4a69 (build succeeded, app relaunched)

## 2026-08-20 22:31 - OK - claude/google-brave-icon-664463
- "The web search row now shows the Brave icon instead of Google's, matching the browser it opens in"
- merged commits:
  - 97e1f3d The web search row now shows the Brave icon instead of Google's, matching the browser it opens in
- main is now at: 09d13c0 (build succeeded, app relaunched)

## 2026-08-20 22:32 - OK - claude/sasuke-theme-replacement-74c118
- "Sasuke's entrance is now the anime close-up of his Rinnegan filling the screen, with the tomoe turning in his eye, chakra rolling out of it and more Rinnegan opening around the edges"
- merged commits:
  - 9e388fb Sasuke's entrance is now the anime close-up of his Rinnegan filling the screen, with the tomoe turning in his eye, chakra rolling out of it and more Rinnegan opening around the edges
- main is now at: a19b9f9 (build succeeded, app relaunched)

## 2026-08-20 22:36 - OK - claude/sasuke-theme-replacement-74c118
- "Keep the tomoe in Sasuke's eye their proper comma shape while it spins, instead of stretching them as they come round"
- merged commits:
  - 9118872 Keep the tomoe in Sasuke's eye their proper comma shape while it spins, instead of stretching them as they come round
- main is now at: 357003a (build succeeded, app relaunched)

## 2026-08-20 22:41 - OK - claude/sasuke-theme-icon-f6eb90
- "Show the actual purple Rinnegan next to the search field in the Sasuke theme, instead of the flat menu-bar badge"
- merged commits:
  - 7aacf98 Show the actual purple Rinnegan next to the search field in the Sasuke theme, instead of the flat menu-bar badge
- main is now at: 9fb70d7 (build succeeded, app relaunched)

## 2026-08-20 22:43 - CONFLICT - claude/last-watched-episode-memory-c418cb
- merge into main conflicted and was aborted; main is untouched.
- unmerged commits:
  - f5e9dc3 Spidey remembers where you got to in a show: watching the pitt s1e6 saves it, an open episode page or the Mac going to sleep saves it by itself, and typing the show name offers Resume and Next up
- fix: in the worktree run 'git merge main', resolve the conflicts, commit, then re-run scripts/ship.sh

## 2026-08-20 22:44 - OK - claude/last-watched-episode-memory-c418cb
- "Spidey remembers where you got to in a show: watching the pitt s1e6 saves it, an open episode page or the Mac going to sleep saves it by itself, and typing the show name offers Resume and Next up"
- merged commits:
  - d6057cc Merge main into last-watched-episode-memory
  - f5e9dc3 Spidey remembers where you got to in a show: watching the pitt s1e6 saves it, an open episode page or the Mac going to sleep saves it by itself, and typing the show name offers Resume and Next up
- main is now at: 01dbfec (build succeeded, app relaunched)

## 2026-08-20 22:49 - OK - claude/sasuke-theme-icon-f6eb90
- "Sasuke's search field now reads Awaken the Rinnegan, matching the eye beside it"
- merged commits:
  - b9da601 Sasuke's search field now reads Awaken the Rinnegan, matching the eye beside it
- main is now at: 10fbe3d (build succeeded, app relaunched)

## 2026-08-20 22:50 - OK - claude/sasuke-theme-replacement-74c118
- "Leave Sasuke's eye exactly as the artwork has it and spin only the six commas on the spot, instead of pasting a drawn Rinnegan over it"
- merged commits:
  - d30676a Leave Sasuke's eye exactly as the artwork has it and spin only the six commas on the spot, instead of pasting a drawn Rinnegan over it
- main is now at: 28c7928 (build succeeded, app relaunched)

## 2026-08-20 23:38 - CONFLICT - claude/sharingan-theme-animation-632707
- merge into main conflicted and was aborted; main is untouched.
- unmerged commits:
  - 7d812d3 New Sharingan theme in black and red: the eye itself is the icon, and its entrance turns the moon behind Itachi's pole into a spinning Sharingan
- fix: in the worktree run 'git merge main', resolve the conflicts, commit, then re-run scripts/ship.sh

## 2026-08-20 23:39 - OK - claude/sharingan-theme-animation-632707
- "New Sharingan theme in black and red: the eye itself is the icon, and its entrance turns the moon behind Itachi's pole into a spinning Sharingan"
- merged commits:
  - b774ddc Merge main into sharingan theme branch
  - 7d812d3 New Sharingan theme in black and red: the eye itself is the icon, and its entrance turns the moon behind Itachi's pole into a spinning Sharingan
- main is now at: f12a26e (build succeeded, app relaunched)

## 2026-08-20 23:45 - OK - claude/sharingan-theme-animation-632707
- "The Sharingan theme runs a deeper blood red: darker iris, darker glow and a darker sky behind it, so the eye is the brightest thing in the frame"
- merged commits:
  - ba8829a The Sharingan theme runs a deeper blood red: darker iris, darker glow and a darker sky behind it, so the eye is the brightest thing in the frame
- main is now at: f1b245c (build succeeded, app relaunched)

## 2026-08-21 00:24 - OK - claude/spidey-github-setup-ec1abc
- "Open source scaffolding: CI, release workflow, contributing and security docs, screenshots in the README"
- merged commits:
  - af626df Open source scaffolding: CI, release workflow, contributing and security docs, screenshots in the README
- main is now at: a0a8951 (build succeeded, app relaunched)

## 2026-08-21 00:31 - OK - main
- "Point the open source docs at github.com/tptresh/sidekick and make ship.sh push main to the public repo"
- merged commits:
  - (none - rebuild/relaunch only)
- main is now at: b1ee39c (build succeeded, app relaunched)

## 2026-08-21 00:43 - OK - main
- "Commit history now uses a GitHub noreply address instead of a personal email"
- merged commits:
  - (none - rebuild/relaunch only)
- main is now at: e296440 (build succeeded, app relaunched)

## 2026-08-21 00:52 - OK - main
- "Disclaimer no longer claims the theme artwork is original"
- merged commits:
  - (none - rebuild/relaunch only)
- main is now at: 384bda3 (build succeeded, app relaunched)

## 2026-08-22 15:54 - OK - claude/time-location-lookup-bug-dc2194
- "Time lookups understand more cities, abbreviations like HK, and typos like 'new dehli'"
- merged commits:
  - a4622f9 Time lookups understand more cities, abbreviations like HK, and typos like 'new dehli'
- main is now at: bf2c753 (build succeeded, app relaunched)

## 2026-08-22 18:27 - OK - claude/time-location-lookup-bug-dc2194
- "Time lookups know every country, so 'time in ghana' and 'time in usa' both answer"
- merged commits:
  - ad33498 Time lookups know every country, so 'time in ghana' and 'time in usa' both answer
- main is now at: 5a29728 (build succeeded, app relaunched)

## 2026-08-22 19:14 - OK - claude/phone-ping-consistency-f74535
- "Ping my phone now waits for Find My to be ready and always plays the sound, instead of sometimes just opening the app"
- merged commits:
  - 158c283 Ping my phone now waits for Find My to be ready and always plays the sound, instead of sometimes just opening the app
- main is now at: 87e1218 (build succeeded, app relaunched)

## 2026-10-08 21:15 - OK - main
- "Sidekick switches the Mac to Light Mode at 6:00 and Dark Mode at 16:30 on its own, with both times editable in Settings"
- merged commits:
  - (none - rebuild/relaunch only)
- main is now at: a7a4c36 (build succeeded, app relaunched)

## 2026-10-08 21:15 - OK - main
- "README mentions scheduled light and dark mode"
- merged commits:
  - (none - rebuild/relaunch only)
- main is now at: 3dc2c61 (build succeeded, app relaunched)

## 2026-10-08 21:21 - OK - worktree-watch-movies
- "watching and the sleep auto-save now recognise movie pages, so an open movie gets saved and resumes from its name"
- merged commits:
  - ff8cfec watching and the sleep auto-save now recognise movie pages, so an open movie gets saved and resumes from its name
- main is now at: 084f316 (build succeeded, app relaunched)

## 2026-10-08 21:23 - OK - main
- "Preferences window is wider and resizable, so the theme cards and text no longer get cut off at the edges"
- merged commits:
  - (none - rebuild/relaunch only)
- main is now at: 2e830f7 (build succeeded, app relaunched)

## 2026-10-08 21:26 - OK - worktree-watch-movies
- "while a movie or episode is playing in the front browser tab, typing just 'wa' offers to save it"
- merged commits:
  - 3fd5ed9 while a movie or episode is playing in the front browser tab, typing just 'wa' offers to save it
- main is now at: c2c6678 (build succeeded, app relaunched)

## 2026-10-08 21:27 - OK - worktree-watch-movies
- "typing 'wa' now spots Brave playing a movie, so the quick save actually appears"
- merged commits:
  - e0fac27 typing 'wa' now spots Brave playing a movie, so the quick save actually appears
- main is now at: 883a9b9 (build succeeded, app relaunched)

## 2026-10-08 21:35 - OK - worktree-watch-movies
- "'wa' now works with the movie paused too, and saves the time you're at; resuming shows 'at 1:04:04'"
- merged commits:
  - 9c79b75 'wa' now works with the movie paused too, and saves the time you're at; resuming shows 'at 1:04:04'
- main is now at: d9974aa (build succeeded, app relaunched)

## 2026-10-08 21:40 - OK - worktree-watch-movies
- "Cmd+Return works again (forgets a saved show, pins clipboard items), and resuming a movie skips to the saved time once it starts playing"
- merged commits:
  - f6e2818 Cmd+Return works again (forgets a saved show, pins clipboard items), and resuming a movie skips to the saved time once it starts playing
- main is now at: 132f0b9 (build succeeded, app relaunched)

## 2026-10-08 21:44 - OK - worktree-watch-movies
- "resume only skips to the saved time after 5 seconds of steady playback, retries through reloads and failed jumps, and never overwrites the saved time while waiting"
- merged commits:
  - 1b7ad73 resume only skips to the saved time after 5 seconds of steady playback, retries through reloads and failed jumps, and never overwrites the saved time while waiting
- main is now at: 13256aa (build succeeded, app relaunched)

## 2026-10-08 21:47 - OK - main
- "permissions now survive rebuilds: the app is signed with a stable local certificate instead of a new ad-hoc identity each build"
- merged commits:
  - (none - rebuild/relaunch only)
- main is now at: a49846f (build succeeded, app relaunched)

## 2026-10-09 00:15 - OK - worktree-ui-overhaul
- "only the Spider-Man and Batman themes remain; Sasuke (Rinnegan) and Sharingan are gone, and anyone on them falls back to Spider-Man"
- merged commits:
  - b173666 only the Spider-Man and Batman themes remain; Sasuke (Rinnegan) and Sharingan are gone, and anyone on them falls back to Spider-Man
- main is now at: 3532e40 (build succeeded, app relaunched)

## 2026-10-09 00:18 - OK - worktree-ui-overhaul
- "search order: 'usd to gbp' now converts, installed apps beat same-named websites, typed addresses like github.com open directly, half-typed words no longer let toggles jump above apps, and learned picks never outrank calculator or conversion answers"
- merged commits:
  - a893595 search order: 'usd to gbp' now converts, installed apps beat same-named websites, typed addresses like github.com open directly, half-typed words no longer let toggles jump above apps, and learned picks never outrank calculator or conversion answers
- main is now at: 3a74e61 (build succeeded, app relaunched)

## 2026-10-09 00:19 - OK - worktree-ui-overhaul
- "fixes: site checks retry and ignore offline moments instead of flagging every site dead for days, password manager copies stay out of clipboard history, brightness never goes fully black, timers ring on time after sleep, and a taken hotkey no longer replaces the working one"
- merged commits:
  - e4ef378 fixes: site checks retry and ignore offline moments instead of flagging every site dead for days, password manager copies stay out of clipboard history, brightness never goes fully black, timers ring on time after sleep, and a taken hotkey no longer replaces the working one
- main is now at: 57095db (build succeeded, app relaunched)

## 2026-10-09 00:22 - OK - worktree-ui-overhaul
- "the menu bar icon now opens a panel with today's weather, the automatic Light and Dark switch times, and a Keeping Mac Awake indicator (plus a dot on the icon) while caffeinate is on"
- merged commits:
  - e0beb2a the menu bar icon now opens a panel with today's weather, the automatic Light and Dark switch times, and a Keeping Mac Awake indicator (plus a dot on the icon) while caffeinate is on
- main is now at: 0ccea92 (build succeeded, app relaunched)

## 2026-10-09 00:24 - OK - worktree-ui-overhaul
- "Preferences redesigned: a sidebar with General, Appearance, Media Sites, Clipboard, Claude Code and Permissions, settings grouped into cards, a health dot on every media site, and a banner plus sidebar badge when any site fails its check"
- merged commits:
  - a62e1a8 Preferences redesigned: a sidebar with General, Appearance, Media Sites, Clipboard, Claude Code and Permissions, settings grouped into cards, a health dot on every media site, and a banner plus sidebar badge when any site fails its check
- main is now at: d8de45c (build succeeded, app relaunched)

## 2026-10-09 00:29 - OK - worktree-ui-overhaul
- "menu bar panel polish: clicking the icon again closes it, the date and weather are fresh on every open, the forecast never gets stuck loading, Preferences says when a site check could not run because the Mac was offline, and file names like main.rs stay file searches"
- merged commits:
  - f94a3f9 menu bar panel polish: clicking the icon again closes it, the date and weather are fresh on every open, the forecast never gets stuck loading, Preferences says when a site check could not run because the Mac was offline, and file names like main.rs stay file searches
- main is now at: 25514db (build succeeded, app relaunched)

## 2026-10-09 00:30 - OK - worktree-ui-overhaul
- "README describes the new menu bar panel, the redesigned Preferences sidebar, and the Location permission used for weather"
- merged commits:
  - 3a176dc README describes the new menu bar panel, the redesigned Preferences sidebar, and the Location permission used for weather
- main is now at: e89216f (build succeeded, app relaunched)

## 2026-10-09 00:49 - OK - worktree-ui-overhaul
- "menu bar panel redesigned in a clean native style: weather shows instantly from a saved forecast and refreshes in the background, an always-visible Keep Mac Awake switch with a coffee cup beside the menu bar icon while it is on, the Light and Dark schedule, and quiet Preferences and Quit links (no Search button)"
- merged commits:
  - 7d4c9ff menu bar panel redesigned in a clean native style: weather shows instantly from a saved forecast and refreshes in the background, an always-visible Keep Mac Awake switch with a coffee cup beside the menu bar icon while it is on, the Light and Dark schedule, and quiet Preferences and Quit links (no Search button)
- main is now at: 404f833 (build succeeded, app relaunched)

## 2026-10-09 00:53 - OK - worktree-ui-overhaul
- "Preferences is now one clean page grouped like System Settings, with health dots and a not-responding summary for media sites, instead of sidebar panes"
- merged commits:
  - cc4e462 Preferences is now one clean page grouped like System Settings, with health dots and a not-responding summary for media sites, instead of sidebar panes
- main is now at: 5eda68d (build succeeded, app relaunched)

## 2026-10-09 09:27 - OK - worktree-futuristic-redesign
- "Futuristic redesign of the menu bar panel and Preferences (glass cards, new website picker, weather city box); the menu bar emblem turns red (Spider-Man) or white (Batman) while Keep Mac Awake is on and the bat is bolder; weather now finds your location (falls back to network location or a typed city); Lock Screen really locks, Light/Dark retries if it fails, timers survive a relaunch"
- merged commits:
  - 3b7d34c Futuristic redesign of the menu bar panel and Preferences (glass cards, new website picker, weather city box); the menu bar emblem turns red (Spider-Man) or white (Batman) while Keep Mac Awake is on and the bat is bolder; weather now finds your location (falls back to network location or a typed city); Lock Screen really locks, Light/Dark retries if it fails, timers survive a relaunch
- main is now at: c42d36f (build succeeded, app relaunched)

## 2026-10-09 09:37 - OK - worktree-futuristic-redesign
- "Batman menu bar icon is a hollow outline while Keep Mac Awake is off and fills in white when it is on"
- merged commits:
  - 05501e5 Batman menu bar icon is a hollow outline while Keep Mac Awake is off and fills in white when it is on
- main is now at: 9cfdbb3 (build succeeded, app relaunched)

## 2026-10-09 09:44 - OK - worktree-futuristic-redesign
- "Batman theme removed: Spider-Man is the only theme, so Preferences no longer shows a theme picker and typing batman no longer offers a theme switch"
- merged commits:
  - 6928d44 Batman theme removed: Spider-Man is the only theme, so Preferences no longer shows a theme picker and typing batman no longer offers a theme switch
- main is now at: 0207ab7 (build succeeded, app relaunched)

## 2026-10-09 18:24 - OK - refresh-ui
- "Liquid Glass redesign: the search panel, menu bar panel, Preferences and large type share one dark glass style with a restrained red accent, always dark, solid fallbacks for Reduce Transparency; plus fixes for clipped text, a stuck shortcut box and layout jumps"
- merged commits:
  - 10e096c Buttons on the glass cards are quiet capsules (theme red when prominent) so they never melt into the card, glass cards stay visibly separate, and the search panel's glass is a touch darker so grey subtitles stay readable over bright wallpapers
  - cef0507 Liquid Glass look for the search panel, menu bar panel, Preferences and large type, always dark: frosted glass cards with soft depth, red kept for the selected row, switched-on icons and focus, larger rounded corners, no glows; long weather errors and large type text no longer get cut off, the clipboard stepper no longer shifts as the count grows, and the shortcut box highlights in the theme red
- main is now at: 1d92664 (build succeeded, app relaunched)

## 2026-10-09 18:26 - OK - refresh-core
- "Reliability: your chosen hotkey is never overwritten by the fallback, sites are not flagged dead while offline or waking, timers reload at launch and ring once, weather keeps the city you typed and refreshes after wake, favicons retry, currency works on a fresh install, clipboard trims at once; menu bar panel and Preferences always dark"
- merged commits:
  - 20d5854 Reliability: your chosen hotkey is never overwritten by the fallback, sites are not flagged dead while offline or waking, timers reload at launch and ring once, weather keeps the city you typed and refreshes after wake, favicons retry, currency works on a fresh install, clipboard trims at once; menu bar panel and Preferences always dark
  - c24c50c Merge main into refresh-core
  - 95b33d6 Lowering the clipboard history size in Preferences trims the history straight away
  - 6efe9b4 Weather ignores stale lookups while typing a city and refreshes after wake; favicons retry after offline; currency cache folder created on fresh installs
  - 008b3e7 Hotkey keeps Cmd+Space as your choice while it falls back, site checks ignore offline moments even with one site, timers restored at launch and ring once
- main is now at: f127a21 (build succeeded, app relaunched)

## 2026-10-09 18:32 - OK - refresh-glass
- "Liquid Glass now shows through in the menu bar dropdown and Preferences too: both are see-through dark glass like the search panel, instead of glass cards on a solid background"
- merged commits:
  - f36fca5 Liquid Glass now shows through in the menu bar dropdown and Preferences too: both are see-through dark glass like the search panel, instead of glass cards on a solid background
- main is now at: b89a2d4 (build succeeded, app relaunched)

## 2026-10-09 18:34 - OK - refresh-search
- "Search: right first row for everyday queries (68 checked), typing about 2.5x lighter, find my opens Find My, play stays a music command, no stray Watch rows for win, bm or typed addresses, stale file results no longer linger, and short prefixes still open sites"
- merged commits:
  - a12fdc0 Merge main into refresh-search
  - fe6678c Short prefixes like ste, tar or wire open the site again instead of a toggle or restart row; only a fully typed command word like play pushes a site down
  - 3a40f6e Typing a non-Latin name no longer offers an unreadable punycode homepage guess; show-title parsing keeps splitting on long dashes without the banned character in source
  - fea4fa6 Typing is faster: the site directory is scored once per keystroke instead of three times, and address and conversion patterns are compiled once (about 2.3 ms down to 0.9 ms of search work per keystroke)
  - aa74b15 File results stay in step with typing: another query's files no longer sit on top (or open on Return) while you type, a logo or rate refresh no longer restarts the file search, and a pending search can no longer crash the app or leak into the drop menu
  - 78cb69b Search picks the right first row in more cases: "find my" opens Find My, "spell" on a correct word keeps the word, "play" stays a music command, and win/bm/typed addresses no longer add Watch rows
- main is now at: 5585790 (build succeeded, app relaunched)

## 2026-10-09 18:37 - OK - refresh-integrations
- "Ping my iPhone rings your own device, never a family member's, and always says why when it cannot; scripts can no longer hang; music, volume, tabs, window snapping, menu search, toggles, quit and kill say when they fail; Calendar updates at once"
- merged commits:
  - 1f0ab54 Ping my iPhone rings your own device, never a family member's, and always says why when it cannot; scripts can no longer hang; music, volume, tabs, window snapping, menu search, toggles, quit and kill say when they fail; Calendar updates at once
  - 0b3498b Merge main into refresh-integrations
  - add3b4e Menu items that open a dialog (Print, Save As, Export) no longer trigger a false Could not run that menu item warning
  - 802b337 Turning Bluetooth on or off no longer reports a false failure while the radio is still switching
  - 1ebb171 Pause, next and other music commands say Nothing is playing when Spotify and Music are closed, instead of showing nothing
  - 9686410 Quit or kill an app that is not running now says so instead of showing an unrelated row first; kill node shows one row that ends every node process instead of identical duplicates
  - 0f34f25 Switching to a tab that has since been closed now says the tab is gone instead of opening whichever tab took its place; locking the screen waits long enough for a first-time permission prompt
  - be03eb2 Ping my iPhone and ping AirPods Pro now ring your own device first, even when a family device has the plain default name; typing a full device name still picks that exact device
  - 72f02d0 Music, volume, tab switching, window snapping, menu search and reminders now say when they did not work; scripts can no longer hang, and Calendar shows new events at once
  - 933714b Focus, quit, kill, Wi-Fi, Bluetooth, dark mode and keep-awake now say when they did not work instead of failing silently; Wi-Fi and Bluetooth switches no longer freeze the panel
  - afd7899 Ping my phone finds the device even when typed without the apostrophe or with extra words, prefers your own iPhone over a family one, and always says why when it could not ring
- main is now at: b84e244 (build succeeded, app relaunched)

## 2026-10-09 18:48 - OK - refresh-polish
- "Menu bar dropdown matches the search panel: one glass slab with the date, weather, switches and hairline dividers instead of cards; Light and Dark times are picked from preset buttons in the dropdown and Preferences; media sites in Preferences show their real logos"
- merged commits:
  - e63125d Menu bar dropdown matches the search panel: one glass slab with the date, weather, switches and hairline dividers instead of cards; Light and Dark times are picked from preset buttons in the dropdown and Preferences; media sites in Preferences show their real logos
- main is now at: d68ac6e (build succeeded, app relaunched)

## 2026-10-09 19:08 - OK - main
- "Keep Mac Awake now also holds off sleep on battery and with the lid closed; the menu bar switch says which it is doing, and Preferences explains the one admin grant it needs"
- merged commits:
  - (none - rebuild/relaunch only)
- main is now at: 252cccd (build succeeded, app relaunched)
