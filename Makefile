APP_NAME = Sidekick
BIN_NAME = Spidey
BUNDLE_ID = dev.opensource.spidey
BUILD_DIR = .build/release
APP_DIR = build/$(APP_NAME).app
SIGN_IDENTITY = Sidekick Local Signing
SIGN_KEYCHAIN = $(HOME)/Library/Keychains/sidekick-signing.keychain-db
SIGN_STAMP = build/.signing-identity

.PHONY: app signing build test icon clean run prune guard-main-checkout

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
	@if [ -f Resources/sasuke.png ]; then cp Resources/sasuke.png $(APP_DIR)/Contents/Resources/; fi
	@# Privacy grants are tied to the code identity. With the local signing
	@# certificate (scripts/setup-signing.sh) the identity is the same on every
	@# build, so grants survive rebuilds. Without it the build is ad-hoc signed,
	@# which is a new identity each time.
	@if security find-certificate -c "$(SIGN_IDENTITY)" $(SIGN_KEYCHAIN) >/dev/null 2>&1; then \
		scripts/setup-signing.sh >/dev/null; \
		security unlock-keychain -p sidekick-local $(SIGN_KEYCHAIN); \
		codesign --force --sign "$(SIGN_IDENTITY)" $(APP_DIR); \
	else \
		echo "note: ad-hoc signing; run scripts/setup-signing.sh once so permissions survive rebuilds"; \
		codesign --force --sign - $(APP_DIR); \
	fi
	@# When the identity did change, the old grants go stale but linger in
	@# System Settings and features fail silently. Reset them so the next launch
	@# prompts fresh. A stable identity skips this entirely.
	@new_req="$$(codesign -d -r- $(APP_DIR) 2>&1 | sed -n 's/^designated => //p')"; \
	if [ "$$new_req" != "$$(cat $(SIGN_STAMP) 2>/dev/null)" ]; then \
		echo "Code identity changed; resetting privacy grants"; \
		for service in Accessibility AddressBook Calendar Reminders AppleEvents; do \
			tccutil reset $$service $(BUNDLE_ID) || true; \
		done; \
	fi; \
	case "$$new_req" in *"certificate leaf"*) echo "$$new_req" > $(SIGN_STAMP);; *) rm -f $(SIGN_STAMP);; esac
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

# One-time: create the local signing certificate so rebuilds keep permissions.
signing:
	@scripts/setup-signing.sh

icon:
	swift scripts/makeicon.swift Resources/AppIcon.icns

run: app
	open $(APP_DIR)

clean:
	rm -rf .build build
