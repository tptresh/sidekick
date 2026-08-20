# Spidey

An open source, superhero-themed launcher for macOS, inspired by [Alfred](https://www.alfredapp.com/) and Spotlight. Press your hotkey, type, and go.

Native Swift + SwiftUI. No Electron, no dependencies, one small menu bar agent.

## Features

- **App launcher**: fuzzy search across /Applications, /System/Applications, and ~/Applications
- **File search**: just type a file name and matching files appear alongside other results; Spotlight search of every indexed file merged with Spidey's own index of Documents, Downloads, and Desktop, ranked so exact and close name matches come first; multi-word queries work (`pitch deck` finds `Pitch Deck Final.pptx`); `find <name>` runs a files-only deep search with more results; Return opens, Cmd+Return reveals in Finder, and results can be dragged out of the panel
- **Calculator**: type `2+2*5` and Return copies the result
- **Unit and currency conversion**: `100 usd to gbp`, `5km in miles`, `72f to c`. Exchange rates are fetched once a day and cached, so currency conversion works offline after the first fetch
- **World clock**: `time in tokyo` (or `tokyo time`) shows the current time, date, and offset from you
- **Emoji search**: `emoji fire` and Return copies 🔥; searches names and keywords across a curated set
- **Color tools**: type `#E02128` or `rgb(224, 33, 40)` for a live swatch with hex, RGB, and HSL rows, each one Return-copies
- **Password generator**: `pw` or `pw 24` shows fresh random passwords (with and without symbols), Return copies one
- **Dictionary**: `define word` and `spell word`
- **System commands**: sleep, lock, restart, shut down, log out, empty trash, screen saver, eject (destructive ones ask for a confirming second Return)
- **Quit and force-kill**: `quit chrome` asks an app to quit; `kill chrome` force-quits it, and `kill node` also reaches background processes by name
- **Window snapping**: `left half`, `right half`, quarters, `maximize`, `center` move the front window (one-time Accessibility permission; the row walks you through granting it)
- **Toggles**: `dark mode`, `wifi`, `bluetooth` (direct with blueutil installed, otherwise opens Settings), and `caffeinate` to keep the Mac awake until you turn it off
- **Ping your Apple devices**: `ping my iphone`, `ping airpods`, or `find my keys` plays a sound on the device through the Find My app; any name from your Find My list works (`ping tanush's macbook`). Uses the same one-time Accessibility permission as window snapping, and if a step cannot be automated Find My is left open on the device so finishing is one click
- **Timers**: `timer 10m tea` rings with a notification and a sound; `timers` lists running ones and Return cancels
- **Focus modes**: type `dnd` or `do not disturb` and Return to silence notifications; `dnd off` turns them back on. No setup: macOS only exposes Focus switching through Apple Shortcuts, so on first use Spidey generates the needed shortcut, signs it locally, and macOS shows a one-click "Add Shortcut" confirmation; the moment you add it, the Focus flips, and every later use is instant. Custom modes work by convention: name any shortcut `Focus: <Mode>` (a single "Set Focus" action, e.g. `Focus: Work`) and it appears as a command automatically
- **Web search keywords**: `google`, `amazon`, `wiki`, `imdb`, `gh`, `maps`. `amazon death note manga` opens the Amazon results directly
- **YouTube and media**: `youtube lofi beats` opens the YouTube search in Brave; bare `youtube`, `netflix`, or `crunchyroll` open the homepage in Brave
- **Show search**: type any show name and Spidey offers to open it on Netflix, Crunchyroll, Prime Video, or Disney+ (toggle each in Preferences)
- **Custom media sites**: add any streaming site's homepage URL in Preferences and show searches include it too (Spidey finds the show there with a site-scoped Google search). A background check runs every few days and flags sites that stop resolving
- **Website directory**: type a mainstream site or brand name (`vinted`, `rimowa`, `grand seiko`, ...) and its homepage opens in Brave; unknown names get a homepage guess
- **Claude Code**: `claude fix the spelling issue on my web page` starts a Claude Code session with that prompt in your chosen folder, in the Claude desktop app when installed, otherwise in Terminal
- **Clipboard history**: everything you copy (text, files, images) is kept; type `clip` to browse and search it, Return copies an item back
- **Drag and drop**: drop files onto the panel to open them, reveal them, copy them, or copy their paths; dropped files are also recorded into clipboard history
- **Site logos**: web rows show the real favicon of the site (Netflix, Crunchyroll, Disney+, ...), fetched once and cached locally
- **Hero themes**: Spider-Man (black and deep red) and Batman (black and silver grey), switchable in Preferences along with the menu bar emblem

Everything that opens a website prefers [Brave](https://brave.com/); if Brave is not installed, your default browser is used.

## Install

Requires macOS 13+ and Xcode (or the Command Line Tools with a Swift 5.9+ toolchain).

```
git clone <this repo>
cd Spidey
make app
open build/Sidekick.app
```

Optional: copy `build/Sidekick.app` into /Applications and enable "Launch Spidey at login" in Preferences.

## The Cmd+Space hotkey

Spidey defaults to Cmd+Space, but macOS gives that key to Spotlight. To hand it to Spidey:

1. System Settings > Keyboard > Keyboard Shortcuts > Spotlight
2. Untick "Show Spotlight search"
3. Relaunch Spidey (or re-pick the hotkey in Preferences)

Until then, Spidey automatically falls back to Option+Space. You can record any other combo in Preferences from the menu bar icon.

## Preferences

Click the mask icon in the menu bar > Preferences:

- Hero theme (Spider-Man, Batman)
- The hotkey that opens Spidey
- Which streaming services appear for show searches
- Custom media sites, with a per-site link health dot and a Check Now button
- The folder Claude Code sessions start in
- Clipboard history size, and clearing it
- Launch at login

## Extending the website directory

Add your own sites without rebuilding: create `~/Library/Application Support/Spidey/sites.json` with name to URL pairs:

```json
{
  "my intranet": "https://intranet.example.com",
  "vinted": "https://www.vinted.fr"
}
```

User entries override the built-in list. To extend the built-in list for everyone, edit `Sources/Spidey/Providers/SiteDirectoryProvider.swift` and open a pull request.

## Permissions

- **Automation**: the first system command asks for permission to control System Events or Finder. This is standard macOS behavior for launchers.
- **Files**: on first launch macOS asks for access to Documents, Downloads, and Desktop. Click Allow on each, or file search cannot see those folders (macOS also hides them from Spidey's Spotlight queries until then). Optionally grant Spidey Full Disk Access in System Settings > Privacy & Security for the widest Spotlight coverage.
- **Shortcuts**: Focus switching runs shortcuts through the `shortcuts` command line tool. The Do Not Disturb ones are generated by Spidey and confirmed by you with one click on first use; custom `Focus: <Mode>` ones you create yourself. No extra permission is needed.
- **Accessibility**: window snapping and device pinging share one Accessibility permission; the result row walks you through granting it on first use. Pinging also triggers the standard Automation prompt for System Events, since it drives the Find My app by scripting its UI (macOS offers no other door into Find My).
- Spidey needs no accessibility permission for its hotkey.

## Development

```
swift build        # debug build
swift test         # unit tests
make app           # release .app bundle in build/
make icon          # regenerate Resources/AppIcon.icns
```

Dev flags: `Spidey --show "query"` opens the panel on launch; `Spidey --snapshot <dir>` renders sample panels to PNGs and exits.

## Disclaimer

Spidey is a fan-made open source tool. It is not affiliated with, endorsed by, or connected to Marvel, DC, Alfred, or any of the trademark holders whose characters inspired its themes. The theme artwork is original, simplified cartoon iconography.

## License

MIT. See [LICENSE](LICENSE).
