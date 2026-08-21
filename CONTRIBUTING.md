# Contributing to Spidey

Spidey is the repo; **Sidekick** is the app it builds. It is a native macOS
launcher written in Swift and SwiftUI, with no third-party dependencies, and
the intention is to keep it that way.

Bug reports, small fixes, new providers, and additions to the website directory
are all welcome.

## Getting set up

You need macOS 13 or later and a Swift 5.9+ toolchain (Xcode, or the Command
Line Tools).

```bash
git clone https://github.com/tptresh/sidekick.git
```

```bash
cd sidekick && make build && make test
```

Then build and run the real app:

```bash
make app && open build/Sidekick.app
```

`make app` ad-hoc signs the bundle, which changes its code identity, so macOS
treats every build as a new app and the previous Accessibility, Contacts,
Calendar, Reminders, and Automation grants go stale. The Makefile resets them
deliberately so the next launch prompts fresh. That is expected after a
rebuild, not a bug.

Only one Sidekick runs at a time: a launching copy terminates any older one,
because two instances would both claim the menu bar item and the global hotkey.

Useful dev flags on the binary:

- `Spidey --show "query"` opens the panel on launch with the query prefilled
- `Spidey --snapshot <dir>` renders sample panels to PNGs and exits
- `Spidey --entrance <theme> <dir>` captures frames of a theme entrance

## How the code is arranged

```
Sources/Spidey/
  main.swift, AppDelegate.swift, HotKey.swift   the agent, the hotkey, the panel
  Engine/     QueryEngine (the view model), Fuzzy, Calculator, Result
  Providers/  one file per kind of result: apps, files, emoji, contacts, ...
  Services/   storage and background work: stores, caches, watchers, SetupCenter
  UI/         SwiftUI views and the theme art
```

Every keystroke runs the query through `SpideyViewModel.refresh()` in
`Sources/Spidey/Engine/QueryEngine.swift`, which asks each provider for rows,
merges them, applies learned ranking, and sorts by score.

### Adding a provider

A provider is a plain `enum` with one static entry point that turns a query
into rows. It returns an empty array for queries it does not handle, and it
must be cheap, because it runs on every keystroke. Anything slow (a network
call, a Spotlight query) belongs in a `Services/` type that caches, with the
provider reading the cache and the engine re-running when fresh data lands.

```swift
// Sources/Spidey/Providers/WeatherProvider.swift
import AppKit

// "weather london": current conditions for a place.
enum WeatherProvider {
    static func results(for query: String) -> [ResultItem] {
        guard query.lowercased().hasPrefix("weather ") else { return [] }
        let place = String(query.dropFirst("weather ".count))
        return [
            ResultItem(
                title: "18C in \(place)",
                subtitle: "Return copies the temperature",
                icon: .symbol("cloud.sun"),
                score: 0.9,
                rankingKey: "weather:\(place.lowercased())",
                action: { /* ... */ }
            )
        ]
    }
}
```

Then add one line to `refresh()` alongside the other providers:

```swift
commandItems += WeatherProvider.results(for: trimmed)
```

Notes on the fields:

- `score` decides the ordering. Look at nearby providers for the range that
  puts a row above or below app matches rather than inventing a number.
- `rankingKey` is the stable identity used to learn what a user picks for a
  given query. Set it whenever the same row can be picked again; leave it `nil`
  for one-off rows that should never be learned.
- `secondaryAction` is what Cmd+Return does. Copying instead of opening is the
  usual pairing.

### Adding a site to the directory

Anyone can extend the directory locally with
`~/Library/Application Support/Spidey/sites.json`. To add a site for everyone,
edit the list in `Sources/Spidey/Providers/SiteDirectoryProvider.swift` and open
a pull request. Mainstream, widely recognised names only, please.

### Permissions and tools

If your feature needs a permission or a command line tool, register it in
`Sources/Spidey/Services/SetupCenter.swift` so it is requested up front at
launch and shows in Preferences under "Permissions & Tools". Do not add a
feature that surprises the user with a missing piece the first time they use
it.

## House rules

- **No em dashes (U+2014) anywhere under `Sources/`.** Use a plain hyphen or
  rewrite the sentence. This covers comments too, which keeps the check simple,
  and it covers the character written as a `\u{2014}` escape, which reaches the
  UI just the same. CI fails the build if one appears.
- **No third-party dependencies.** `Package.swift` has none and should stay
  that way.
- **Comment the non-obvious constraint, not the obvious code.** The `tccutil`
  note in the Makefile is the house style: it explains why a surprising line
  exists.
- **Keep names ordinary and readable.** The theme art is playful; the code is
  not.
- Write commit messages about user-visible behaviour, in plain English.

## Tests

`make test` runs the suite in `Tests/SpideyTests/`. Pure logic (parsing,
scoring, stores, ranking) is tested; anything that talks to AppKit, the system,
or the network is not, so keep the testable part separable.

Add a test when you add parsing or ranking behaviour. Fixing a bug in that kind
of code usually means adding the case that was wrong.

## Sending a pull request

Fork, branch, and open a PR against `main`. Keep it to one coherent change.
Fill in the template: what changes, and the query to type to see it.

CI runs `make build`, `make test`, and the em dash check on every PR.

You will see branches named `claude/...`, an auto-generated `SHIPLOG.md`, and a
`CLAUDE.md` describing a local trunk-based workflow. That is how the maintainer
works on their own machine, with several sessions in git worktrees merging
straight to `main`. It does not apply to you: contributors use ordinary forks
and pull requests, and nothing in that workflow needs to run on your side.
Never edit `SHIPLOG.md` by hand.

## Scope

Things likely to be accepted: a new provider that fits the shape above, a fix
with a test, better matching or ranking, additions to the site directory, docs.

Things likely to be declined: dependencies, a rewrite of the UI framework,
features that need a server or an account, anything that phones home. Spidey
makes network calls only for exchange rates, favicons, and searches the user
explicitly asked for.

## Code of conduct

By taking part you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

## Licence

Contributions are licensed under the [MIT License](LICENSE), the same as the
rest of the project.
