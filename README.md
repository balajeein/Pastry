# Pastry — Native macOS Clipboard Manager & Math Engine

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![macOS 11.0+](https://img.shields.io/badge/macOS-11.0%2B-apple.svg)](https://www.apple.com/macos/)
[![Swift 5.0](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![Privacy: 100% Offline](https://img.shields.io/badge/Privacy-100%25%20Offline-success.svg)](#privacy--security-model)

**Pastry** is a lightweight, ultra-fast, open-source macOS clipboard manager and inline mathematical evaluation tool. Designed to feel like a native macOS system utility, Pastry runs silently in your menu bar and gives you instant access to your clipboard history and real-time calculation engine via a global keyboard shortcut (`⌘⇧V`).

---

## Features

- **Native & Lightweight:** Built purely with Swift, SwiftUI, AppKit, and Carbon. Zero third-party dependencies.
- **Menu Bar Resident:** Runs cleanly as a status bar application (`LSUIElement`) without clogging your Dock or `Cmd+Tab` switcher.
- **Global Shortcut (`⌘⇧V`):** Summon the floating clipboard panel instantly from any application. Custom shortcuts supported.
- **Auto-Paste Integration:** Automatically restores focus to your target application and simulates `⌘V` to paste selected history items.
- **Built-in Hand-written Math Engine:** Instantly detects, parses, and evaluates math expressions copied to your clipboard (arithmetic, trigonometry, logarithms, equation solving, and unit conversions).
- **Automatic Screenshot Tracking:** Detects new Desktop screenshots in real-time, displays local disk thumbnails, and indexes them into your history.
- **Real-Time Fuzzy Search:** Search through copied text, URLs, image dimensions, and file paths with instantaneous filtering.
- **Privacy First & Password Manager Aware:** 100% offline local processing. Automatically ignores transient/concealed pasteboard data from password managers (1Password, Bitwarden, Keychain).
- **Adaptive Dark & Light Modes:** Dynamically matches your macOS system appearance with a glassmorphic design.

---

## Privacy & Security Model

Pastry is engineered from the ground up to respect your privacy:

* **100% Offline Execution:** Zero network connections. No telemetry, no analytics, no crash reporters, no tracking SDKs.
* **Local Storage Only:** History data is stored strictly on your local disk inside `~/Library/Application Support/Pastry/`.
* **Sensitive Data Exclusion:** Ignores pasteboard types marked as transient or concealed (`org.nspasteboard.TransientType`, `org.nspasteboard.ConcealedType`, `com.agilebits.onepassword`).
* **Flexible Cleanup:** Offers an optional *"Clear history on quit"* setting and instant history deletion controls.

---

## Built-in Calculator Engine

Pastry includes a custom, zero-dependency recursive descent mathematical parser and evaluator. When text containing a mathematical expression is copied or typed into Pastry, the engine automatically calculates the result.

### Supported Math Syntax

| Category | Supported Syntax / Functions | Example Inputs | Result |
| :--- | :--- | :--- | :--- |
| **Basic Arithmetic** | `+`, `-`, `*`, `/`, `%` (modulo), `^` (power), `!` (factorial) | `25 * 4`, `2^10`, `5!` | `100`, `1,024`, `120` |
| **Parentheses & Precedence** | Standard algebraic precedence with nested parentheses | `(10 + 5) * 4 / 2` | `30` |
| **Trigonometry** | `sin()`, `cos()`, `tan()`, `asin()`, `acos()`, `atan()` | `sin(90 deg)`, `cos(pi rad)` | `1`, `-1` |
| **Logarithms & Exponents** | `log()`, `ln()`, `log2()`, `exp()` | `log10(1000)`, `ln(e)` | `3`, `1` |
| **Roots & Absolute Value** | `sqrt()`, `cbrt()`, `abs()` | `sqrt(144)`, `cbrt(27)` | `12`, `3` |
| **Equation Solving** | Linear and quadratic equation solvers | `2x + 10 = 20`, `x^2 - 9 = 0` | `x = 5`, `x = 3, -3` |
| **Implicit Multiplication** | Omitted multiplication operators before parentheses & functions | `5(10 + 2)`, `2sin(45 deg)` | `60`, `1.414` |

---

## User Interface & Controls

| Shortcut / Action | Action Description |
| :--- | :--- |
| `⌘⇧V` *(default)* | Open / Close Pastry floating clipboard panel |
| `↑` / `↓` Arrow Keys | Navigate through clipboard history items |
| `Return` / `Enter` | Paste selected item into currently active application |
| `⌘C` (when panel open) | Copy selected item back to active clipboard |
| `Esc` | Close clipboard panel |
| `Type search text` | Filter history by text content, URL host, or image properties |

---

## Requirements

* **Operating System:** macOS 11.0 (Big Sur) or later.
* **Architectures:** Apple Silicon (`arm64`) and Intel (`x86_64`) Universal 2.
* **Required Permissions:**
  * **Accessibility Permission:** Required to restore focus to target applications and trigger synthesized `⌘V` paste events.
  * **Desktop Folder Access:** Required to monitor local Desktop screenshot creation.

---

## Installation

### Pre-built Binary
Download the latest `.dmg` release from the **[GitHub Releases](../../releases)** page:
1. Open `Pastry.dmg`.
2. Drag `Pastry.app` to your `Applications` folder.
3. Launch Pastry and grant **Accessibility** permission when prompted.

### Building from Source

Ensure you have Xcode Command Line Tools installed (`xcode-select --install`).

```bash
# 1. Clone the repository
git clone https://github.com/balajeein/Pastry.git
cd Pastry

# 2. Setup local development signing identity (run once)
./Scripts/setup-signing.sh

# 3. Build debug binary and launch
./Scripts/dev.sh
```

---

## Developer & Build Reference

Pastry includes Makefile targets and modular shell scripts for rapid development and production builds:

```bash
make dev            # Rebuild debug binary & launch active application
make app            # Compile optimized release build/Pastry.app
make dmg            # Package build/Pastry.app into build/Pastry.dmg
make run            # Launch built application
make test           # Execute entire SwiftPM unit test suite
```

### Script Pipeline Details

* [`Scripts/dev.sh`](file:///Users/balajee/Documents/projects/pastry/Scripts/dev.sh): Fast incremental debug compilation (`-Onone`, `-g`) signed with local `Pastry Dev` certificate to preserve Accessibility permissions across re-compiles.
* [`Scripts/build.sh`](file:///Users/balajee/Documents/projects/pastry/Scripts/build.sh): Compiles Universal 2 release binary (`arm64` + `x86_64`) targeting macOS 11.0.
* [`Scripts/release.sh`](file:///Users/balajee/Documents/projects/pastry/Scripts/release.sh): Production release pipeline requiring Apple Developer ID, performing Hardened Runtime signing, DMG packaging, Apple Notarization (`notarytool`), and Gatekeeper stapling.

---

## Testing

Pastry includes automated unit tests covering the math engine, clipboard store, deduplication, and screenshot monitoring logic.

Run tests using Swift Package Manager:

```bash
swift test
```

Or run via Makefile:

```bash
make test
```

---

## Project Architecture

```
Pastry/
├── Pastry/                      # Core application source modules
│   ├── App/                     # AppDelegate and app lifecycle coordinator
│   ├── Calculator/              # Hand-written tokenizer, parser, AST & evaluator
│   ├── Clipboard/               # ClipboardManager, ClipboardStore, ScreenshotMonitor
│   ├── Hotkey/                  # GlobalHotkeyManager (Carbon hotkey registration)
│   ├── MenuBar/                 # MenuBarController (NSStatusItem menu bar integration)
│   ├── Panel/                   # PastryPanelController, ClipboardPanelView, ClipboardRowView
│   ├── Paste/                   # PasteService (focus restoration & CGEvent ⌘V simulation)
│   ├── Resources/               # Info.plist, Pastry.entitlements, AppIcon.icns
│   ├── Settings/                # SettingsManager, SettingsView, ShortcutRecorderView
│   ├── Storage/                 # ImageStorage (disk thumbnail & image storage)
│   └── Utilities/               # RelativeFormatter
├── PastryApp/                   # Application executable entry point (main.swift)
├── Tests/                       # SwiftPM unit test target
│   └── PastryTests/             # Calculator, Clipboard, and Screenshot test suites
├── Scripts/                     # Modular build, development, and release scripts
├── Package.swift                # Swift Package Manager manifest
├── Makefile                     # Shortcut build commands
├── VERSION                      # Single source of truth for versioning
└── README.md                    # Project documentation
```

---

## Contributing

Contributions are welcome! If you find a bug or have a feature request:

1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4. Ensure all tests pass (`swift test`).
5. Push to the branch (`git push origin feature/AmazingFeature`).
6. Open a Pull Request.

---

## License

Pastry is open-source software licensed under the **[GNU General Public License v3.0 (GPLv3)](https://www.gnu.org/licenses/gpl-3.0.html)**.

```
Pastry — Native macOS Clipboard Manager & Math Engine
Copyright (C) 2026 Balajee

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
```
