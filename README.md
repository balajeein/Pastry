# Pastry – Native macOS Clipboard Manager & Math Engine

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![macOS 11.0+](https://img.shields.io/badge/macOS-11.0%2B-apple.svg)](https://www.apple.com/macos/)
[![Swift 5.0](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![Privacy: 100% Offline](https://img.shields.io/badge/Privacy-100%25%20Offline-success.svg)](#privacy--security-model)

**Pastry** is a lightweight, ultra‑fast, open‑source macOS clipboard manager with a built‑in math evaluation engine. It lives in the menu bar, remembers clipboard history, and evaluates mathematical expressions instantly.

---

## Features

- **Native & Lightweight** – Pure Swift, SwiftUI, AppKit and Carbon. No third‑party dependencies.
- **Menu‑Bar Resident** – Runs as a status‑bar app (`LSUIElement`).
- **Global Shortcut (`⌘⇧V`)** – Open the clipboard panel from any app.
- **Auto‑Paste** – Restores focus and simulates `⌘V` after selection.
- **Hand‑written Math Engine** – Arithmetic, trigonometry, logarithms, equation solving, unit conversion.
- **Screenshot Tracking** – Real‑time monitoring of Desktop screenshots.
- **Fuzzy Search** – Instant filtering of text, URLs, images, and file paths.
- **Privacy‑First** – 100 % offline, no telemetry, respects password‑manager data.
- **Adaptive Dark/Light Modes** – Glassmorphic UI that follows system appearance.

---

## Project Architecture

```text
Pastry/
├── Pastry/                      # Core app source modules
│   ├── App/                     # AppDelegate & lifecycle
│   ├── Calculator/              # Tokenizer, parser, AST & evaluator
│   ├── Clipboard/               # Clipboard manager, store, screenshot monitor
│   ├── Hotkey/                  # Global hotkey handling (Carbon)
│   ├── MenuBar/                 # Status‑item controller
│   ├── Panel/                   # Clipboard panel UI
│   ├── Paste/                   # Focus restoration & ⌘V simulation
│   ├── Resources/               # Info.plist, entitlements, icons
│   ├── Settings/                # Preferences UI & storage
│   ├── Storage/                 # Image storage & thumbnails
│   └── Utilities/               # Helper utilities
├── PastryApp/                   # Entry point (`main.swift`)
├── Tests/                       # SwiftPM test suite
│   └── PastryTests/             # Calculator, clipboard, screenshot tests
├── Scripts/                     # Build, dev, release helpers
├── Package.swift                # Swift Package Manager manifest
├── Makefile                     # Convenience build targets
└── README.md                    # This documentation
```

---

## Installation

### Pre‑built Binary
1. Download the latest `.dmg` from the **[GitHub Releases](https://github.com/balajeein/Pastry/releases)**.
2. Open `Pastry.dmg` and drag `Pastry.app` into **Applications**.
3. Launch Pastry and grant **Accessibility** permission when prompted.

### Build from Source
```bash
# Clone the repo
git clone https://github.com/balajeein/Pastry.git
cd Pastry

# Install Xcode command‑line tools (if not already present)
xcode-select --install

# Set up a local signing identity (run once)
./Scripts/setup-signing.sh

# Build and launch a debug version
./Scripts/dev.sh
```

You can also use the Makefile shortcuts:
```bash
make dev   # Rebuild debug binary & launch
make app   # Build optimized release app
make dmg   # Package `Pastry.app` into a DMG
make test  # Run the SwiftPM test suite
```

---

## Usage

- **Open Clipboard Panel** – Press `⌘⇧V` (default) from any app.
- **Navigate** – Use `↑` / `↓` arrows to browse history.
- **Paste** – Press `Enter` to paste the selected item.
- **Copy Back** – `⌘C` while the panel is open copies the item back to the clipboard.
- **Search** – Type to filter by text, URL, image dimensions, or file path.
- **Math Evaluation** – Copy a mathematical expression; the built‑in engine evaluates it instantly and shows the result.

---

## Testing

```bash
# Swift Package Manager
swift test

# Or via Makefile
make test
```

---

## Contributing

Please read the full guidelines in [`CONTRIBUTING.md`](CONTRIBUTING.md). In short:
1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/YourFeature`).
3. Commit your changes.
4. Ensure all tests pass (`swift test`).
5. Push and open a Pull Request.

---

## License

Pastry is licensed under the **GNU General Public License v3.0** or later. See the [LICENSE](LICENSE) file for details.

---

## Privacy & Security Model

- **100 % Offline** – No network connections, telemetry, or crash reporters.
- **Local Storage** – History stored in `~/Library/Application Support/Pastry/`.
- **Sensitive Data Exclusion** – Automatically ignores transient or concealed pasteboard types (e.g., 1Password, Bitwarden).
- **Optional History Clearing** – Settings allow clearing history on quit or manual deletion.

---

*For more details, explore the source code under `Pastry/` or the documentation in the `Scripts/` directory.*