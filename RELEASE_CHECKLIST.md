# Pastry — v1.0 Product Release Checklist

Use this checklist before publishing a new public release of Pastry.

---

## 1. PRE-RELEASE AUDIT & VERIFICATION

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

### Menu Bar & Dock
- [ ] **Menu Bar Only**: Status item displays clipboard icon; app does NOT appear in the Dock or Cmd+Tab switcher.
- [ ] **Menu Items**: "Open Clipboard", "Pause History", "Clear History", "Settings...", "Quit Pastry" operate cleanly.
- [ ] **Dark Mode / Light Mode**: Template status icon and visual effect background adjust natively for OS theme.

### Accessibility Permission & Setup
- [ ] **Permission Status**: Correctly detects granted vs. missing status in Settings.
- [ ] **UX Guidance**: Explains why Accessibility permission is needed ("Pastry needs Accessibility permission to paste clipboard items...").
- [ ] **Settings Link**: "Grant Access..." / "Open Settings" opens macOS System Settings → Privacy & Security → Accessibility.
- [ ] **Local Signing**: `setup-signing.sh` certificate identity preserves Accessibility across `./dev.sh` rebuilds.

### Code & Metadata Audit
- [ ] **No Secrets**: No private keys, passwords, or notarization credentials committed to Git.
- [ ] **No Debug Code**: No dummy test buttons, debug logs, or fake fallbacks.
- [ ] **Version Number**: `VERSION` file updated with target `MARKETING_VERSION` (e.g. `1.0.0`) and `BUILD_NUMBER` (e.g. `1`).
- [ ] **Git Working Tree**: Clean working tree (`git status`).

---

## 2. RELEASE BUILD & NOTARIZATION

- [ ] **Run Release Script**:
  ```bash
  ./release.sh
  ```
- [ ] **Build Verification**: Optimized release binary compiled successfully in `build/Pastry.app`.
- [ ] **Developer ID Signature**: Verified with `codesign --verify --deep --strict build/Pastry.app`.
- [ ] **Hardened Runtime**: Enabled (`--options runtime`).
- [ ] **Entitlements**: `Pastry/Resources/Pastry.entitlements` applied.
- [ ] **DMG Package**: `build/Pastry.dmg` created with drag-and-drop Applications shortcut.
- [ ] **Apple Notarization**: Submitted via `xcrun notarytool submit` and approved.
- [ ] **Staple Ticket**: Ticket stapled using `xcrun stapler staple build/Pastry.dmg`.

---

## 3. GIT TAGGING & DISTRIBUTION

- [ ] **Create Git Version Tag**:
  ```bash
  git tag -a v1.0.0 -m "Pastry v1.0.0 Release"
  git push origin v1.0.0
  ```
- [ ] **Create GitHub Release**: Attach `build/Pastry.dmg`.
- [ ] **Clean Test**: Download DMG on a clean Mac / user account, drag to Applications, launch, grant Accessibility, and verify core workflow.

---

## 4. POST-RELEASE VERIFICATION

- [ ] **Fresh Installation**: Verify application launches without Gatekeeper warnings.
- [ ] **First Launch Alert**: Welcome alert displays correctly on initial launch.
- [ ] **Persistence**: Copying items, quitting app, and reopening restores saved history.
