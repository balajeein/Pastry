# Pastry

A tiny, native macOS clipboard-history utility that feels like a built-in macOS feature.

**Copy something → Pastry remembers it → press ⌘⇧V → choose an item → it's automatically pasted.**

## Features

- **Menu-bar only** — no Dock icon, no Cmd+Tab presence
- **Global shortcut** — press `⌘⇧V` from any app to open clipboard history
- **Automatic paste** — select an item and it's pasted instantly into your active app
- **Text, images, URLs, files** — supports all major clipboard types
- **Search** — instantly filter your history
- **Keyboard navigation** — Arrow keys + Enter to select, Escape to close
- **Persistent history** — survives app restarts
- **Duplicate handling** — repeated copies move the item to the top
- **Privacy-first** — everything stays local, nothing is ever sent over the network

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac
- **Accessibility permission** required for automatic paste (Pastry simulates ⌘V)

## Building

Pastry is compiled directly with `swiftc` via the included Makefile.

```bash
# Build the .app bundle
make app

# Build and create a .dmg installer
make dmg

# Clean build artifacts
make clean
```

The output is placed in the `build/` directory:
- `build/Pastry.app` — the application bundle
- `build/Pastry.dmg` — the distributable disk image

### Prerequisites

- Xcode Command Line Tools (`xcode-select --install`)
- The CLT version must match the installed Swift compiler version

## Installation

### From DMG

1. Open `Pastry.dmg`
2. Drag `Pastry.app` into your Applications folder
3. Launch Pastry
4. Grant Accessibility permission when prompted (required for auto-paste)

### From Source

```bash
make app
open build/Pastry.app
```

## Usage

1. **Copy things** as you normally would throughout the day
2. When you need something from earlier, press **⌘⇧V**
3. A small floating panel appears near your cursor
4. **Click** an item or use **↑↓ Arrow keys + Enter**
5. The item is automatically pasted into your active app
6. Done — Pastry disappears

### Menu Bar

Click the clipboard icon in the menu bar for:
- **Open Clipboard** — same as ⌘⇧V
- **Pause History** — temporarily stop recording
- **Clear History** — delete all stored items
- **Settings** — configure shortcut, limits, privacy
- **Quit Pastry** — exit the app

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| ⌘⇧V | Open clipboard history |
| ↑ / ↓ | Navigate items |
| Enter | Select and paste |
| Escape | Close panel |
| Type anything | Search/filter |

## Settings

- **Global Shortcut** — change from ⌘⇧V to any modifier+key combo
- **Launch at Login** — start Pastry automatically
- **History Limits** — 20 text, 10 image, 10 other items (configurable)
- **Pause History** — temporarily stop recording clipboard changes
- **Clear History on Quit** — auto-delete on exit
- **Accessibility Status** — check/grant permission

## Privacy

Pastry is designed with clipboard privacy as a core principle:

- **No network requests** — clipboard data never leaves your Mac
- **No analytics or telemetry** — zero tracking
- **No cloud sync** — everything stored locally in `~/Library/Application Support/Pastry/`
- **No logging of clipboard contents** — only safe metadata is logged
- **Password manager filtering** — items marked as transient/concealed (e.g., from 1Password) are ignored
- **Clear History** — delete all stored data at any time

## Architecture

```
Pastry/
├── App/           — AppDelegate, lifecycle management
├── Clipboard/     — ClipboardManager, ClipboardItem, ClipboardStore
├── Hotkey/        — GlobalHotkeyManager (Carbon hotkey registration)
├── Paste/         — PasteService (focus restoration + CGEvent ⌘V simulation)
├── MenuBar/       — MenuBarController (NSStatusItem)
├── Panel/         — PastryPanelController, ClipboardPanelView, ClipboardRowView
├── Settings/      — SettingsManager, SettingsView
├── Storage/       — ImageStorage (thumbnails + full images on disk)
├── Utilities/     — RelativeFormatter
└── Resources/     — Info.plist, AppIcon.icns
```

## Code Signing for Distribution

For local development, the app is ad-hoc signed (`codesign -s -`).

For distribution outside the Mac App Store:

1. Obtain a **Developer ID Application** certificate from Apple
2. Sign with: `codesign -s "Developer ID Application: Your Name" --deep --options runtime build/Pastry.app`
3. Notarize: `xcrun notarytool submit build/Pastry.dmg --apple-id you@example.com --team-id TEAMID --password @keychain:AC_PASSWORD`
4. Staple: `xcrun stapler staple build/Pastry.dmg`

## License

MIT
