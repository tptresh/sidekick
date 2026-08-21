# Security policy

## Reporting a vulnerability

Please report privately rather than opening a public issue:

**[Open a private security advisory](https://github.com/tptresh/sidekick/security/advisories/new)**

Include what you found, how to reproduce it, and what an attacker gets out of
it. Spidey is maintained by one person in their spare time, so expect a first
reply within about a week. There is no bounty.

Once a fix ships, you are credited in the advisory unless you would rather not
be.

## Supported versions

The latest release and the current `main`. Older releases are not patched.

## What the app can do, and why that matters

Sidekick asks for broad permissions, so it is worth knowing what an exploit
would reach. If you find a way to make any of these run without the user
choosing it, that is a vulnerability worth reporting:

- **Accessibility**: drives other apps' windows, menu bars, and the Find My UI
- **Automation (Apple Events)**: scripts System Events, Finder, Brave/Chrome,
  Spotify/Music, and Terminal
- **Contacts, Calendar, Reminders**: reads the address book and calendars,
  creates reminders
- **Files**: searches Documents, Downloads, and Desktop, and queries Spotlight
- **Clipboard**: records everything copied, including whatever a password
  manager puts there, into a local history

Everything above stays on the machine. Data lives in
`~/Library/Application Support/Spidey/` and is never uploaded anywhere.

## Things that are working as intended

These are documented behaviours rather than bugs, though a report showing one
can be triggered *without* the user's action is very much in scope:

- **Script commands** run arbitrary executables from
  `~/Library/Application Support/Spidey/scripts/`. Anything that can write an
  executable file into a user's home directory can already run code as that
  user. Arguments are passed as `argv` directly, never through a shell.
- **Clipboard history** keeps copied secrets in a local file until the cap
  prunes them or the user clears the history in Preferences.
- **Releases are ad-hoc signed, not notarized.** Downloads are quarantined and
  need `xattr -dr com.apple.quarantine` before they open. There is no
  Developer ID certificate on this project.
- **`sites.json`, `searches.json`, and `aliases.json`** let a user point
  commands at any URL. They are the user's own files.

## Network

Sidekick talks to the network for exactly three things: a daily exchange rate
fetch, favicons for site rows, and periodic link health checks on custom media
sites. Everything else opens a URL in the user's browser because they asked for
it. There is no telemetry, no analytics, and no update check.
