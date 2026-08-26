import SwiftUI
import Carbon

struct ShortcutRecorderView: View {
    @ObservedObject var settings = SettingsManager.shared

    // Recording state
    @State private var isRecording   = false
    @State private var liveModifiers = "" // Shows held modifier keys before final key is pressed
    @State private var monitors: [Any] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            HStack(spacing: 10) {
                Text("Global Shortcut:")
                    .font(.system(size: 13))

                // ── Shortcut pill ──────────────────────────────────
                Button(action: toggleRecording) {
                    HStack(spacing: 6) {
                        if isRecording {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                            Text(liveModifiers.isEmpty ? "Press shortcut…" : "\(liveModifiers) …")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.primary)
                        } else {
                            Text(settings.hotKeyDisplayString)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isRecording
                                  ? Color.accentColor.opacity(0.12)
                                  : Color.primary.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(
                                        isRecording ? Color.accentColor : Color.primary.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                    )
                }
                .buttonStyle(.plain)
                .help(isRecording
                      ? "Press a key combination, or Escape to cancel"
                      : "Click to record a new shortcut")

                // Cancel ×
                if isRecording {
                    Button(action: stopRecording) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .help("Cancel")
                }

                Spacer()

                // Reset to ⌘⇧V
                if #available(macOS 12.0, *) {
                    Button("Reset to Default") {
                        stopRecording()
                        settings.resetToDefault()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!isRecording &&
                              settings.hotKeyCode == 9 &&
                              settings.hotKeyModifiers == 768)
                } else {
                    Button("Reset to Default") {
                        stopRecording()
                        settings.resetToDefault()
                    }
                    .controlSize(.small)
                    .disabled(!isRecording &&
                              settings.hotKeyCode == 9 &&
                              settings.hotKeyModifiers == 768)
                }
            }

            // Conflict warning
            if settings.registrationFailed {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                    Text("Shortcut conflicts with another app. Try a different combination.")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }

            // Hint
            Text(isRecording
                 ? "Hold ⌘ ⌥ ⌃ ⇧ then press a key. Escape cancels."
                 : "Click the shortcut pill above to change it. Default: ⌘⇧V")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .onDisappear { stopRecording() }
    }

    // MARK: - Actions

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording   = true
        liveModifiers = ""

        // Global monitor — captures keys pressed in OTHER apps while Settings is open
        let gMon = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { ev in
            handleNSEvent(ev)
        }

        // Local monitor — captures keys inside our own window (and lets us consume Escape)
        let lMon = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { ev in
            handleNSEvent(ev)
            return nil  // consume so it doesn't reach the text field / other responders
        }

        var newMonitors: [Any] = []
        if let g = gMon { newMonitors.append(g) }
        if let l = lMon { newMonitors.append(l) }
        monitors = newMonitors
    }

    private func handleNSEvent(_ event: NSEvent) {
        // ── flagsChanged: update the live modifier preview ────────
        if event.type == .flagsChanged {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var preview = ""
            if flags.contains(.control) { preview += "⌃" }
            if flags.contains(.option)  { preview += "⌥" }
            if flags.contains(.shift)   { preview += "⇧" }
            if flags.contains(.command) { preview += "⌘" }
            DispatchQueue.main.async { liveModifiers = preview }
            return
        }

        guard event.type == .keyDown else { return }

        // Escape → cancel without changing the shortcut
        if event.keyCode == 53 {
            DispatchQueue.main.async { stopRecording() }
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Must include at least ⌘, ⌃, or ⌥ to avoid bare-letter conflicts
        guard flags.contains(.command) ||
              flags.contains(.control) ||
              flags.contains(.option)  else { return }

        // Build Carbon modifier mask
        var carbonFlags: UInt32 = 0
        if flags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
        if flags.contains(.shift)   { carbonFlags |= UInt32(shiftKey) }
        if flags.contains(.option)  { carbonFlags |= UInt32(optionKey) }
        if flags.contains(.control) { carbonFlags |= UInt32(controlKey) }

        DispatchQueue.main.async {
            // SettingsManager.didSet → registers the hotkey + sets registrationFailed
            settings.hotKeyCode      = UInt32(event.keyCode)
            settings.hotKeyModifiers = carbonFlags
            stopRecording()
        }
    }

    private func stopRecording() {
        isRecording   = false
        liveModifiers = ""
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
    }
}

struct GeneralSettingsTab: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var hasAccessibility = PasteService.shared.isAccessibilityPermissionGranted()
    
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Launch Pastry at login", isOn: $settings.isLaunchAtLogin)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13))
                
                ShortcutRecorderView()
                
                Divider()
                    .padding(.vertical, 4)
                
                Text("Accessibility Permission")
                    .font(.system(size: 13, weight: .bold))
                
                HStack(spacing: 8) {
                    Image(systemName: hasAccessibility ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(hasAccessibility ? .green : .orange)
                        .font(.system(size: 14))
                    
                    Text(hasAccessibility ? "Status: Granted" : "Status: Not Granted")
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    if #available(macOS 12.0, *) {
                        Button(hasAccessibility ? "Open Settings" : "Grant Access...") {
                            if !hasAccessibility {
                                PasteService.shared.requestAccessibilityPermission()
                            } else {
                                PasteService.shared.openAccessibilitySettings()
                            }
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(hasAccessibility ? "Open Settings" : "Grant Access...") {
                            if !hasAccessibility {
                                PasteService.shared.requestAccessibilityPermission()
                            } else {
                                PasteService.shared.openAccessibilitySettings()
                            }
                        }
                    }
                }
                
                Text("Pastry needs Accessibility permission to paste clipboard items into the application you're currently using.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
        }
        .padding()
        .onAppear {
            self.hasAccessibility = PasteService.shared.isAccessibilityPermissionGranted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            self.hasAccessibility = PasteService.shared.isAccessibilityPermissionGranted()
        }
        .onReceive(timer) { _ in
            self.hasAccessibility = PasteService.shared.isAccessibilityPermissionGranted()
        }
    }
}

struct HistorySettingsTab: View {
    @ObservedObject var settings = SettingsManager.shared
    
    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 14) {
                Text("Clipboard Retention Limits")
                    .font(.system(size: 13, weight: .bold))
                
                HStack {
                    Text("Text & Link items:")
                    Spacer()
                    Stepper(value: $settings.textHistoryLimit, in: 5...100) {
                        Text("\(settings.textHistoryLimit) items")
                            .font(.system(size: 13, design: .monospaced))
                    }
                }
                
                HStack {
                    Text("Image items:")
                    Spacer()
                    Stepper(value: $settings.imageHistoryLimit, in: 5...50) {
                        Text("\(settings.imageHistoryLimit) items")
                            .font(.system(size: 13, design: .monospaced))
                    }
                }
                
                HStack {
                    Text("Other files & data:")
                    Spacer()
                    Stepper(value: $settings.otherHistoryLimit, in: 5...50) {
                        Text("\(settings.otherHistoryLimit) items")
                            .font(.system(size: 13, design: .monospaced))
                    }
                }
                
                Text("Once limits are reached, the oldest items are automatically removed from disk storage.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
        }
        .padding()
    }
}

struct PrivacySettingsTab: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var showingClearConfirmation = false
    
    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 14) {
                Text("Privacy Controls")
                    .font(.system(size: 13, weight: .bold))
                
                Toggle("Pause clipboard tracking", isOn: $settings.isHistoryPaused)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13))
                
                Toggle("Pause auto screenshot tracking", isOn: $settings.isScreenshotTrackingPaused)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13))
                
                Toggle("Clear history on quit", isOn: $settings.clearHistoryOnQuit)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13))
                
                Divider()
                    .padding(.vertical, 4)
                
                HStack {
                    if #available(macOS 12.0, *) {
                        Button(role: .destructive, action: { showingClearConfirmation = true }) {
                            Text("Clear All Clipboard History")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.bordered)
                        .confirmationDialog("Are you sure you want to clear all clipboard history? This will delete all cached text, files, and image thumbnails from your local disk.", isPresented: $showingClearConfirmation) {
                            Button("Clear", role: .destructive) {
                                ClipboardStore.shared.clearHistory()
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    } else {
                        Button(action: { showingClearConfirmation = true }) {
                            Text("Clear All Clipboard History")
                                .foregroundColor(.red)
                        }
                        .alert(isPresented: $showingClearConfirmation) {
                            Alert(
                                title: Text("Clear All Clipboard History"),
                                message: Text("Are you sure you want to clear all clipboard history? This will delete all cached text, files, and image thumbnails from your local disk."),
                                primaryButton: .destructive(Text("Clear")) {
                                    ClipboardStore.shared.clearHistory()
                                },
                                secondaryButton: .cancel()
                            )
                        }
                    }
                    Spacer()
                }
                
                Text("Pastry works entirely locally. Clipboard contents never leave your Mac and are stored inside your Application Support directory.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
        }
        .padding()
    }
}

public struct SettingsView: View {
    @State private var selectedTab = "general"
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag("general")
            
            HistorySettingsTab()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag("history")
            
            PrivacySettingsTab()
                .tabItem {
                    Label("Privacy", systemImage: "lock")
                }
                .tag("privacy")
        }
        .frame(width: 440, height: 280)
    }
}
