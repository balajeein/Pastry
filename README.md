# Pastry — Native macOS Clipboard History Utility

Pastry is a lightweight, fast, native macOS clipboard-history utility built to feel like an integral macOS system feature.

It runs quietly in the menu bar, monitors your clipboard, and provides instant history access via a global keyboard shortcut (`⌘⇧V`). Selecting an item automatically restores focus and pastes it directly into your active application.

---

## Features

- **Menu Bar Only**: Runs silently without a Dock icon or `Cmd+Tab` clutter (`LSUIElement`).
- **Global Keyboard Shortcut**: Press `⌘⇧V` (or your custom shortcut) from any app to trigger the floating panel.
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
├── PastryApp/                   # Entry point (main.swift)
├── Scripts/                     # Build, signing, and packaging scripts
│   ├── dev.sh                   # Fast debug build & launch cycle
│   ├── build.sh                 # Optimized release .app compilation
│   ├── release.sh               # Production release pipeline (Developer ID + Notarization + DMG)
│   ├── package-dmg.sh           # DMG packaging script
│   └── setup-signing.sh         # Persistent dev certificate setup script
├── VERSION                      # Single source of truth for versioning
├── Makefile                     # Shortcut Makefile targets
├── README.md                    # Developer and product documentation
└── RELEASE_CHECKLIST.md         # Step-by-step pre-release verification
```

---

## Development Workflow

### 1. One-Time Dev Signing Setup

To ensure macOS Accessibility permissions persist across code rebuilds during development:

```bash
./setup-signing.sh
# or
make setup-signing
```

This creates a persistent self-signed `Pastry Dev` certificate in your login Keychain.

### 2. Fast Edit → Build → Run Cycle

To rebuild and launch Pastry during development:

```bash
./dev.sh
# or
make dev
```

What `./dev.sh` does:
1. Stops any currently running development Pastry instance.
2. Compiles Swift sources in **Debug** mode (`-Onone`, `-g`).
3. Signs with the local `Pastry Dev` identity (preserving Accessibility TCC approval).
4. Launches the newly built `build/Pastry.app`.

### Subcommands

```bash
./dev.sh build   # Build debug binary without launching
./dev.sh run     # Launch existing build/Pastry.app
./run.sh         # Quick launcher for build/Pastry.app
```

---

## Versioning

All version numbers are managed from a single source of truth in the `VERSION` file:

```ini
MARKETING_VERSION=1.0.0
BUILD_NUMBER=1
```

The build scripts automatically inject these values into `Info.plist` during compilation.

Pastry uses Semantic Versioning (`MAJOR.MINOR.PATCH`):
- `PATCH` (e.g. `1.0.1`): Bug fixes and minor stability patches.
- `MINOR` (e.g. `1.1.0`): Backward-compatible new capabilities.
- `MAJOR` (e.g. `2.0.0`): Major architectural updates.

---

## Production Release Workflow

### Creating a Release

To compile an optimized release bundle and generate the release DMG:

```bash
./release.sh
# or
make release
```

For dirty working trees during testing, pass `--skip-git-check`:

```bash
./release.sh --skip-git-check
```

### What `./release.sh` Performs

1. Validates clean Git state.
2. Reads `VERSION` for marketing version and build number.
3. Compiles Swift sources with full optimization (`-O`).
4. Signs with **Developer ID Application** certificate and enables **Hardened Runtime** (`--options runtime`).
5. Applies entitlements (`Pastry/Resources/Pastry.entitlements`).
6. Verifies strict code signature (`codesign --verify --strict`).
7. Packages `build/Pastry.dmg` with a drag-and-drop Applications shortcut.
8. Submits to Apple Notary Service via `xcrun notarytool` (if Keychain notarization credentials are present).
9. Staples notarization ticket (`xcrun stapler staple`).
10. Outputs final artifact: `build/Pastry.dmg`.

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

*If Developer ID or Notary credentials are not present, `./release.sh` will complete local compilation, sign with `Pastry Dev`, package the DMG, and report what credentials are missing for Apple notarization.*

---

## Git Release Tagging

When publishing a new public release:

```bash
# 1. Update VERSION file
echo "MARKETING_VERSION=1.0.0" > VERSION
echo "BUILD_NUMBER=1" >> VERSION

# 2. Commit final release changes
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
