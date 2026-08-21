# Pastry — Release & Verification Checklist

Use this checklist to verify Pastry before publishing or testing builds.

---

## WORKFLOW OVERVIEW

Pastry uses two distinct build workflows:

### 1. LOCAL TEST BUILD
- Commands: `./build.sh` followed by `./package-dmg.sh` (or `make app` / `make dmg`)
- Signature: Local `Pastry Dev` certificate (or ad-hoc)
- Target: Local feature testing, UI verification, and manual QA
- Distribution: **NOT FOR PUBLIC DISTRIBUTION**

### 2. PUBLIC PRODUCTION RELEASE
- Command: `./release.sh` (or `make release`)
- Signature: **Developer ID Application** + Hardened Runtime + Entitlements
- Notarization: `xcrun notarytool submit` + `xcrun stapler staple`
- Target: Final public distribution DMG (`build/Pastry.dmg`)

---

## PRE-RELEASE AUDIT & VERIFICATION

### Core Functionality
- [ ] **Text Copying**: Plain text, multiline text, unicode, and emojis copy and render cleanly.
- [ ] **Large Text**: Copying large text blocks (>10,000 chars) handles smoothly without UI freeze.
- [ ] **URLs**: HTTP/HTTPS links format correctly and display clean domain subtitles.
- [ ] **Images**: Image copies generate disk thumbnails, preview cleanly, and copy back to pasteboard.
- [ ] **Other Data**: Complex pasteboard types fall back gracefully.
- [ ] **Deduplication**: Re-copying an item moves it to the top of the history list with updated timestamp.
- [ ] **Retention Limits**: Configured limits (text, image, other) are enforced; evicted items clean up disk files.

### Auto-Paste & Focus Restoration
- [ ] **Normal Paste**: Pastes cleanly into standard macOS text fields, browsers, editors, and Terminal.
- [ ] **Selection Replacement**: Pasting over highlighted text replaces the selected text.
- [ ] **Focus Transfer**: Previously active application regains focus before `⌘V` keystroke simulation.

### Global Shortcut & Window Panel
- [ ] **Global Shortcut**: Pressing `⌘⇧V` (or custom shortcut) opens floating panel from any application.
- [ ] **Background Trigger**: Shortcut works when Pastry is hidden in the background.
- [ ] **Keyboard Navigation**: Up/Down Arrow keys change item selection; Return/Enter pastes; Escape closes.
- [ ] **Instant Search**: Typing filters history immediately; selection resets to top match.
- [ ] **Dismissal**: Panel closes automatically on loss of focus or when item is selected.

### Menu Bar & Accessibility Setup
- [ ] **Menu Bar Only**: Status item displays clipboard icon; app does NOT appear in the Dock or Cmd+Tab switcher.
- [ ] **Menu Items**: "Open Clipboard", "Pause History", "Clear History", "Settings...", "Quit Pastry" operate cleanly.
- [ ] **Accessibility UX**: Clear message ("Pastry needs Accessibility permission to paste clipboard items into the application you're currently using.") and direct link to macOS Settings.
- [ ] **Local Signing**: `setup-signing.sh` certificate identity preserves Accessibility across `./dev.sh` rebuilds.

### Versioning & Metadata Audit
- [ ] **Single Version Source**: `VERSION` file updated with `MARKETING_VERSION` (e.g. `1.0.0`) and `BUILD_NUMBER` (e.g. `1`).
- [ ] **Metadata**: `CFBundleIdentifier` is `com.balajee.Pastry`, `LSUIElement` is `true`.
- [ ] **Git Working Tree**: Working tree is clean (`git status`).

---

## PUBLIC RELEASE EXECUTION (`./release.sh`)

- [ ] **Developer ID Certificate**: `Developer ID Application` certificate installed in Keychain.
- [ ] **Notarization Profile**: Keychain profile `AC_PASSWORD` configured (`xcrun notarytool store-credentials`).
- [ ] **Run Pipeline**:
  ```bash
  ./release.sh
  ```
- [ ] **Build Verification**: Clean release build compiled with `-O`.
- [ ] **Code Signature Verification**:
  ```bash
  codesign --verify --deep --strict build/Pastry.app
  codesign -dv --verbose=4 build/Pastry.app
  ```
- [ ] **Hardened Runtime**: Verified enabled.
- [ ] **Entitlements**: `Pastry/Resources/Pastry.entitlements` verified applied.
- [ ] **DMG Packaging**: `build/Pastry.dmg` created containing `Pastry.app` and Applications symlink.
- [ ] **Notarization**: `xcrun notarytool submit` completed cleanly.
- [ ] **Stapling**: `xcrun stapler staple build/Pastry.dmg` completed.
- [ ] **Gatekeeper Assessment**: `spctl --assess --type open --verbose build/Pastry.dmg` returns accepted.

---

## GIT TAGGING & DISTRIBUTION

- [ ] **Create Git Version Tag**:
  ```bash
  git tag -a v1.0.0 -m "Pastry v1.0.0 Release"
  git push origin main
  git push origin v1.0.0
  ```
- [ ] **Create GitHub Release**: Attach `build/Pastry.dmg`.
- [ ] **Download Test**: Download DMG on a clean Mac / user account, drag to Applications, launch, grant Accessibility, and verify core workflow.
