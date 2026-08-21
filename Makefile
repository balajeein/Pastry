APP_NAME=Pastry
BUILD_DIR=build
APP_BUNDLE=$(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR=$(APP_BUNDLE)/Contents
MACOS_DIR=$(CONTENTS_DIR)/MacOS
RESOURCES_DIR=$(CONTENTS_DIR)/Resources

.PHONY: all dev app release dmg clean run

# Default: optimized release build of .app
all: app

# ── Development (fast, debug, no optimization) ────────────────
dev:
	@./dev.sh

# ── Release .app (optimized, clean build) ─────────────────────
app:
	rm -rf $(APP_BUNDLE)
	mkdir -p $(MACOS_DIR)
	mkdir -p $(RESOURCES_DIR)
	
	# Compile — optimized release
	xcrun swiftc -swift-version 5 -O -o $(MACOS_DIR)/$(APP_NAME) $$(find Pastry PastryApp -name "*.swift")
	
	# Copy Info.plist
	cp Pastry/Resources/Info.plist $(CONTENTS_DIR)/Info.plist
	
	# Copy AppIcon if it exists
	if [ -f Pastry/Resources/AppIcon.icns ]; then \
		cp Pastry/Resources/AppIcon.icns $(RESOURCES_DIR)/AppIcon.icns; \
	fi
	
	# Code sign the app bundle ad-hoc (required for Apple Silicon)
	codesign -s - --force --deep $(APP_BUNDLE)

# ── Full release: .app + .dmg ─────────────────────────────────
release: app dmg

dmg:
	rm -f $(BUILD_DIR)/$(APP_NAME).dmg
	hdiutil create -volname $(APP_NAME) -srcfolder $(APP_BUNDLE) -ov -format UDZO $(BUILD_DIR)/$(APP_NAME).dmg

# ── Launch the built app ──────────────────────────────────────
run:
	@./run.sh

# ── Clean ─────────────────────────────────────────────────────
clean:
	rm -rf $(BUILD_DIR)
