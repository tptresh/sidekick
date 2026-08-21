APP_NAME = Sidekick
BIN_NAME = Spidey
BUNDLE_ID = dev.opensource.spidey
BUILD_DIR = .build/release
APP_DIR = build/$(APP_NAME).app

.PHONY: app build test icon clean run prune guard-main-checkout

build:
	swift build -c release

test:
	swift test

app: guard-main-checkout build
	rm -rf $(APP_DIR)
	mkdir -p $(APP_DIR)/Contents/MacOS $(APP_DIR)/Contents/Resources
	cp $(BUILD_DIR)/$(BIN_NAME) $(APP_DIR)/Contents/MacOS/$(APP_NAME)
	cp Resources/Info.plist $(APP_DIR)/Contents/
	@if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns $(APP_DIR)/Contents/Resources/; fi
	codesign --force --sign - $(APP_DIR)
	@# Ad-hoc signing gives every build a new code identity, so the old
	@# Accessibility grant (needed to drive Find My) goes stale but lingers
	@# in System Settings. Reset it so relaunching prompts fresh instead of
	@# silently failing.
	-tccutil reset Accessibility $(BUNDLE_ID)
	@# Same staleness applies to the Contacts/Calendar/Reminders grants,
	@# and to the Automation (Apple Events) grants for browsers and players.
	-tccutil reset AddressBook $(BUNDLE_ID)
	-tccutil reset Calendar $(BUNDLE_ID)
	-tccutil reset Reminders $(BUNDLE_ID)
	-tccutil reset AppleEvents $(BUNDLE_ID)
	@echo "Built $(APP_DIR)"

# One Mac, one Sidekick.app. A worktree that builds its own bundle produces a
# second app carrying the same CFBundleIdentifier, and macOS then resolves
# "Sidekick" to whichever copy it registered last - so a stale build can launch
# beside the real one. Only the main checkout may produce a bundle.
guard-main-checkout:
	@main_root="$$(dirname "$$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)")"; \
	this_root="$$(git rev-parse --show-toplevel 2>/dev/null)"; \
	if [ -n "$$this_root" ] && [ "$$main_root" != "$$this_root" ]; then \
		echo "make app: refusing to build an app bundle inside a worktree." >&2; \
		echo "  $$this_root" >&2; \
		echo "  Two bundles sharing one bundle id make macOS run two Sidekicks at once." >&2; \
		echo "  To compile-check here:            make build" >&2; \
		echo "  To put your change in the app:    scripts/ship.sh \"what changed\"" >&2; \
		exit 1; \
	fi

# Delete app bundles left behind in worktrees and re-register the real one.
prune:
	@scripts/prune-worktree-apps.sh

icon:
	swift scripts/makeicon.swift Resources/AppIcon.icns

run: app
	open $(APP_DIR)

clean:
	rm -rf .build build
