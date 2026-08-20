# Spidey

An open source, superhero-themed launcher for macOS, inspired by [Alfred](https://www.alfredapp.com/) and Spotlight. Press your hotkey, type, and go.

Native Swift + SwiftUI. No Electron, no dependencies, one small menu bar agent.

## Features

- **App launcher**: fuzzy search across /Applications, /System/Applications, and ~/Applications
- **File search**: Spotlight-backed search of your home folder; Return opens, Cmd+Return reveals in Finder, and results can be dragged out of the panel
- **Calculator**: type `2+2*5` and Return copies the result
- **Dictionary**: `define word` and `spell word`
- **System commands**: sleep, lock, restart, shut down, log out, empty trash, screen saver, eject (destructive ones ask for a confirming second Return)
- **Web search keywords**: `google`, `amazon`, `wiki`, `imdb`, `gh`, `maps`. `amazon death note manga` opens the Amazon results directly
- **YouTube and media**: `youtube lofi beats` opens the YouTube search in Brave; bare `youtube`, `netflix`, or `crunchyroll` open the homepage in Brave
- **Show search**: type any show name and Spidey offers to open it on Netflix, Crunchyroll, Prime Video, or Disney+ (toggle each in Preferences)
- **Website directory**: type a mainstream site or brand name (`vinted`, `rimowa`, `grand seiko`, ...) and its homepage opens in Brave; unknown names get a homepage guess
- **Claude Code**: `claude fix the spelling issue on my web page` opens Terminal in your chosen folder and starts a Claude Code session with that prompt
- **Clipboard history**: everything you copy (text, files, images) is kept; type `clip` to browse and search it, Return copies an item back
- **Drag and drop**: drop files onto the panel to open them, reveal them, copy them, or copy their paths; dropped files are also recorded into clipboard history
- **Hero themes**: Spider-Man (navy and red), Batman (black and yellow), Iron Man (red and gold), switchable in Preferences along with the menu bar icon

Everything that opens a website prefers [Brave](https://brave.com/); if Brave is not installed, your default browser is used.

## Install

Requires macOS 13+ and Xcode (or the Command Line Tools with a Swift 5.9+ toolchain).

```
git clone <this repo>
cd Spidey
make app
open build/Spidey.app
```

Optional: copy `build/Spidey.app` into /Applications and enable "Launch Spidey at login" in Preferences.

## The Cmd+Space hotkey

Spidey defaults to Cmd+Space, but macOS gives that key to Spotlight. To hand it to Spidey:

1. System Settings > Keyboard > Keyboard Shortcuts > Spotlight
2. Untick "Show Spotlight search"
3. Relaunch Spidey (or re-pick the hotkey in Preferences)

Until then, Spidey automatically falls back to Option+Space. You can record any other combo in Preferences from the menu bar icon.

## Preferences

Click the mask icon in the menu bar > Preferences:

- Hero theme (Spider-Man, Batman, Iron Man)
- The hotkey that opens Spidey
- Which streaming services appear for show searches
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

- **Automation**: the first system command or Claude Code launch asks for permission to control System Events, Finder, or Terminal. This is standard macOS behavior for launchers.
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
