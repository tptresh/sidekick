APP_NAME = Spidey
BUILD_DIR = .build/release
APP_DIR = build/$(APP_NAME).app

.PHONY: app build test icon clean run

build:
	swift build -c release

test:
	swift test

app: build
	rm -rf $(APP_DIR)
	mkdir -p $(APP_DIR)/Contents/MacOS $(APP_DIR)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_DIR)/Contents/MacOS/
	cp Resources/Info.plist $(APP_DIR)/Contents/
	@if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns $(APP_DIR)/Contents/Resources/; fi
	codesign --force --sign - $(APP_DIR)
	@echo "Built $(APP_DIR)"

icon:
	swift scripts/makeicon.swift Resources/AppIcon.icns

run: app
	open $(APP_DIR)

clean:
	rm -rf .build build
