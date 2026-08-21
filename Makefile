APP_NAME=Pastry
BUILD_DIR=build

.PHONY: all dev app release dmg clean run setup-signing

# Default: development workflow
all: dev

# ── Development (fast debug build + launch) ───────────────────
dev:
	@./Scripts/dev.sh

# ── Release .app build (optimized) ────────────────────────────
app:
	@./Scripts/build.sh

# ── Full production release: build + sign + dmg + notarize ───
release:
	@./Scripts/release.sh

# ── Package DMG only ──────────────────────────────────────────
dmg:
	@./Scripts/package-dmg.sh

# ── Setup local dev signing identity ──────────────────────────
setup-signing:
	@./Scripts/setup-signing.sh

# ── Launch currently built Pastry.app ──────────────────────────
run:
	@./Scripts/run.sh

# ── Clean build directory ──────────────────────────────────────
clean:
	rm -rf $(BUILD_DIR)
