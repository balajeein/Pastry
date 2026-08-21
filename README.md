# Pastry — Native macOS Clipboard History Utility

Pastry is a lightweight, fast, native macOS clipboard-history utility built to feel like an integral macOS system feature.

It runs quietly in the menu bar, monitors your clipboard, and provides instant history access via a global keyboard shortcut (`⌘⇧V`). Selecting an item automatically restores focus and pastes it directly into your active application.

---

## Features

- **Menu Bar Only**: Runs silently without a Dock icon or `Cmd+Tab` clutter (`LSUIElement`).
- **Global Keyboard Shortcut**: Press `⌘⇧V` (or custom shortcut) from any app to trigger the floating panel.
- **Auto-Paste**: Restores your active application and simulates `⌘V` to paste selected items.
- **Rich Content Types**: Text, URLs, Images (with disk thumbnails), and file paths.
- **Instant Search**: Search through your history in real-time.
- **Keyboard Friendly**: Navigate with `↑` / `↓` Arrow keys, press `Return` to paste, or `Esc` to close.
- **Privacy First**: 100% local storage inside `~/Library/Application Support/Pastry/`. Password manager entries (1Password, concealed, transient) are automatically ignored.
- **Launch at Login**: Integrates with macOS ServiceManagement (`SMAppService`).

---

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon (arm64) or Intel (x86_64) Mac
- **Accessibility Permission**: Required for focus restoration and system paste simulation.

---

## Conceptual Workflows

### DEVELOPMENT WORKFLOW

```
Edit code
   ↓
./dev.sh
   ↓
Test
   ↓
git commit
   ↓
git push
```

### PUBLIC RELEASE WORKFLOW

```
Update VERSION file
   ↓
Test build (./build.sh & ./package-dmg.sh)
   ↓
git commit
   ↓
git tag (e.g. v1.0.0)
   ↓
./release.sh
   ↓
notarized build/Pastry.dmg
   ↓
GitHub Release & Website Download
```

---

## Semantic Versioning

All version numbers are managed from a single source of truth in the `VERSION` file:

```ini
MARKETING_VERSION=1.0.0
BUILD_NUMBER=1
```

Pastry strictly follows Semantic Versioning (`MAJOR.MINOR.PATCH`):

- **PATCH** (`1.0.0` → `1.0.1`): Bug fixes and minor stability patches.
- **MINOR** (`1.0.0` → `1.1.0`): Backward-compatible new capabilities.
- **MAJOR** (`1.0.0` → `2.0.0`): Major architectural or product updates.

---

## Project Structure

```
Pastry/
├── Pastry/                      # Core application source modules
│   ├── App/                     # AppDelegate, app lifecycle coordinator
│   ├── Clipboard/               # ClipboardItem, ClipboardManager, ClipboardStore
│   ├── Hotkey/                  # GlobalHotkeyManager (Carbon hotkey API)
│   ├── MenuBar/                 # MenuBarController (NSStatusItem menu)
│   ├── Panel/                   # PastryPanelController, ClipboardPanelView, ClipboardRowView
│   ├── Paste/                   # PasteService (focus & CGEvent ⌘V simulation)
│   ├── Resources/               # Info.plist, Pastry.entitlements, AppIcon.icns
│   ├── Settings/                # SettingsManager, SettingsView, ShortcutRecorderView
│   ├── Storage/                 # ImageStorage (disk images & thumbnails)
│   └── Utilities/               # RelativeFormatter
├── PastryApp/                   # Executable entry point (main.swift)
├── Scripts/                     # Modular build and release scripts
│   ├── dev.sh                   # Fast debug build & launch cycle
│   ├── build.sh                 # Local optimized release .app compilation
│   ├── release.sh               # Public release pipeline (Developer ID + Notarization + DMG)
│   ├── package-dmg.sh           # Local DMG packaging script
│   └── setup-signing.sh         # Persistent dev certificate setup script
├── VERSION                      # Single source of truth for versioning
├── Makefile                     # Shortcut Makefile targets
├── README.md                    # Developer and product documentation
└── RELEASE_CHECKLIST.md         # Step-by-step pre-release verification
```

---

## Command Reference

### 1. Development (`./dev.sh`)

To rebuild and launch Pastry during development:

```bash
./setup-signing.sh  # Run ONCE to set up 'Pastry Dev' Keychain certificate
./dev.sh            # Rebuild debug + launch
```

What `./dev.sh` performs:
1. Stops any currently running development Pastry instance.
2. Compiles Swift sources in **Debug** mode (`-Onone`, `-g`).
3. Signs with the local `Pastry Dev` identity (preserving Accessibility TCC approval across rebuilds).
4. Launches the newly built `build/Pastry.app`.

### 2. Local Release Build & Testing (`./build.sh`, `./package-dmg.sh`)

```bash
./build.sh          # Compiles optimized build/Pastry.app (local testing)
./package-dmg.sh    # Packages build/Pastry.app into build/Pastry.dmg
./run.sh            # Launches build/Pastry.app
```

### 3. Public Production Release (`./release.sh`)

```bash
./release.sh
```

What `./release.sh` performs:
1. Validates clean Git state (or `--skip-git-check`).
2. Validates `VERSION` file and `Info.plist` bundle identifier (`com.balajee.Pastry`).
3. **REQUIRES** a valid `Developer ID Application` certificate in Keychain (fails cleanly if missing; does NOT fall back to local dev cert).
4. Compiles Swift sources with full optimization (`-O`).
5. Signs with **Developer ID Application** and enables **Hardened Runtime** (`--options runtime`) with entitlements.
6. Verifies strict code signature (`codesign --verify --strict`).
7. Packages `build/Pastry.dmg` with a drag-and-drop Applications shortcut.
8. Submits `build/Pastry.dmg` to Apple Notary Service (`xcrun notarytool submit`).
9. Staples notarization ticket (`xcrun stapler staple`).
10. Outputs final notarized distribution artifact: `build/Pastry.dmg`.

---

## Code Signing & Notarization Setup

### Local Development Signing
Managed automatically via `setup-signing.sh`. Uses the local `Pastry Dev` certificate.

### Developer ID & Notarization Credentials
For public distribution outside the Mac App Store:

1. Install your **Developer ID Application** certificate into your Mac Keychain.
2. Store your Apple Notary credentials in Keychain:
   ```bash
   xcrun notarytool store-credentials "AC_PASSWORD" \
       --apple-id "your-apple-id@example.com" \
       --team-id "YOUR_TEAM_ID"
   ```
3. Run `./release.sh`.

---

## Git Release Tagging

When publishing a new public release:

```bash
# 1. Update VERSION file
echo "MARKETING_VERSION=1.0.0" > VERSION
echo "BUILD_NUMBER=1" >> VERSION

# 2. Commit release changes
git add VERSION
git commit -m "Prepare v1.0.0 release"

# 3. Create semantic version tag and push
git tag -a v1.0.0 -m "Pastry v1.0.0 Release"
git push origin main
git push origin v1.0.0
```

---

## License

MIT License. Copyright © 2026. All rights reserved.
