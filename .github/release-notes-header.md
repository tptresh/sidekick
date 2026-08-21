## Install

1. Download `Sidekick-<version>.zip` below and unzip it.
2. Move `Sidekick.app` to /Applications.
3. Run this once, because the build is ad-hoc signed rather than notarized:

```
xattr -dr com.apple.quarantine /Applications/Sidekick.app
```

4. Open it. The menu bar emblem appears, and Sidekick asks for the permissions
   its features need. Press Option+Space (or Cmd+Space once you free it from
   Spotlight) to open the panel.

Prefer to build it yourself? `git clone`, then `make app`. See the
[README](https://github.com/tptresh/sidekick#install).

---
