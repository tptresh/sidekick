# Screenshots

Regenerate these with the app's own snapshot mode, which renders the panel for a
list of sample queries and exits:

```bash
swift build && .build/debug/Spidey --snapshot /tmp/spidey-snaps
```

The sample queries live in `runSnapshots(into:)` in
`Sources/Spidey/AppDelegate.swift`.

Check every image before committing it. Snapshot mode runs against the real
machine, so queries that hit app or file search will show whatever is actually
installed and whatever files are actually there. Only the ones with no personal
data belong in this folder.
