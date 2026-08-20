import SwiftUI
import Carbon

struct ShortcutRecorderView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var isRecording = false
    @State private var monitor: Any? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Text("Global Shortcut:")
                .font(.system(size: 13))
            
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                Text(isRecording ? "Press combination..." : settings.hotKeyDisplayString)
                    .frame(minWidth: 120)
            }
            .buttonStyle(.bordered)
            .tint(isRecording ? .accentColor : .secondary)
            
            if isRecording {
                Button(action: { stopRecording() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            // Require at least one modifier key
            if flags.isEmpty {
                return event
            }
            
            var carbonFlags: UInt32 = 0
            if flags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
            if flags.contains(.shift) { carbonFlags |= UInt32(shiftKey) }
            if flags.contains(.option) { carbonFlags |= UInt32(optionKey) }
            if flags.contains(.control) { carbonFlags |= UInt32(controlKey) }
            
            settings.hotKeyCode = UInt32(event.keyCode)
            settings.hotKeyModifiers = carbonFlags
            
            self.stopRecording()
            return nil // Intercept event propagation
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
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
                    
                    Button(hasAccessibility ? "Open Settings" : "Grant Access...") {
                        if !hasAccessibility {
                            PasteService.shared.requestAccessibilityPermission()
                        } else {
                            PasteService.shared.openAccessibilitySettings()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Text("Accessibility permission is needed to automatically paste the item back into your active window after choosing it.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
        }
        .padding()
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
                
                Toggle("Clear history on quit", isOn: $settings.clearHistoryOnQuit)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13))
                
                Divider()
                    .padding(.vertical, 4)
                
                HStack {
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
