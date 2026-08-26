import Foundation
import ServiceManagement
import Combine

@available(macOS 13.0, *)
private enum LaunchAtLoginService {
    static var isEnabled: Bool {
        return SMAppService.mainApp.status == .enabled
    }
    
    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            if service.status != .enabled {
                try service.register()
            }
        } else {
            if service.status == .enabled {
                try service.unregister()
            }
        }
    }
}

public class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    // Published properties for SwiftUI binding
    @Published public var textHistoryLimit: Int {
        didSet {
            defaults.set(textHistoryLimit, forKey: "textHistoryLimit")
            ClipboardStore.shared.enforceLimits()
        }
    }
    
    @Published public var imageHistoryLimit: Int {
        didSet {
            defaults.set(imageHistoryLimit, forKey: "imageHistoryLimit")
            ClipboardStore.shared.enforceLimits()
        }
    }
    
    @Published public var otherHistoryLimit: Int {
        didSet {
            defaults.set(otherHistoryLimit, forKey: "otherHistoryLimit")
            ClipboardStore.shared.enforceLimits()
        }
    }
    
    @Published public var isHistoryPaused: Bool {
        didSet {
            defaults.set(isHistoryPaused, forKey: "isHistoryPaused")
        }
    }
    
    @Published public var isScreenshotTrackingPaused: Bool {
        didSet {
            defaults.set(isScreenshotTrackingPaused, forKey: "isScreenshotTrackingPaused")
            if !isScreenshotTrackingPaused {
                ScreenshotMonitor.shared.resumeTracking()
            }
        }
    }
    
    @Published public var clearHistoryOnQuit: Bool {
        didSet {
            defaults.set(clearHistoryOnQuit, forKey: "clearHistoryOnQuit")
        }
    }
    
    @Published public var hotKeyCode: UInt32 {
        didSet {
            defaults.set(hotKeyCode, forKey: "hotKeyCode")
            registrationFailed = !GlobalHotkeyManager.shared.registerHotkey(keyCode: hotKeyCode, modifiers: hotKeyModifiers)
        }
    }
    
    @Published public var hotKeyModifiers: UInt32 {
        didSet {
            defaults.set(hotKeyModifiers, forKey: "hotKeyModifiers")
            registrationFailed = !GlobalHotkeyManager.shared.registerHotkey(keyCode: hotKeyCode, modifiers: hotKeyModifiers)
        }
    }
    
    /// True when the last hotkey registration attempt failed (e.g. conflict with another app).
    @Published public var registrationFailed: Bool = false
    
    @Published public var isLaunchAtLogin: Bool {
        didSet {
            setLaunchAtLogin(enabled: isLaunchAtLogin)
        }
    }
    
    private init() {
        // Load defaults or fallback values
        self.textHistoryLimit = defaults.integer(forKey: "textHistoryLimit") == 0 ? 20 : defaults.integer(forKey: "textHistoryLimit")
        self.imageHistoryLimit = defaults.integer(forKey: "imageHistoryLimit") == 0 ? 10 : defaults.integer(forKey: "imageHistoryLimit")
        self.otherHistoryLimit = defaults.integer(forKey: "otherHistoryLimit") == 0 ? 10 : defaults.integer(forKey: "otherHistoryLimit")
        self.isHistoryPaused = defaults.bool(forKey: "isHistoryPaused")
        self.isScreenshotTrackingPaused = defaults.bool(forKey: "isScreenshotTrackingPaused")
        self.clearHistoryOnQuit = defaults.bool(forKey: "clearHistoryOnQuit")
        
        // Default hotkey: Command + Shift + V (Keycode 9, Modifiers 768)
        let savedKeyCode = defaults.object(forKey: "hotKeyCode") as? UInt32
        let savedModifiers = defaults.object(forKey: "hotKeyModifiers") as? UInt32
        
        self.hotKeyCode = savedKeyCode ?? 9
        self.hotKeyModifiers = savedModifiers ?? 768
        
        if #available(macOS 13.0, *) {
            self.isLaunchAtLogin = LaunchAtLoginService.isEnabled
        } else {
            self.isLaunchAtLogin = defaults.bool(forKey: "isLaunchAtLogin")
        }
    }
    
    public func registerCurrentHotkey() {
        registrationFailed = !GlobalHotkeyManager.shared.registerHotkey(keyCode: hotKeyCode, modifiers: hotKeyModifiers)
    }
    
    public var hotKeyDisplayString: String {
        return GlobalHotkeyManager.getHotkeyString(keyCode: hotKeyCode, modifiers: hotKeyModifiers)
    }
    
    /// Restores the built-in default shortcut: ⌘⇧V
    public func resetToDefault() {
        hotKeyCode = 9        // V
        hotKeyModifiers = 768 // cmdKey | shiftKey
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        defaults.set(enabled, forKey: "isLaunchAtLogin")
        if #available(macOS 13.0, *) {
            do {
                try LaunchAtLoginService.setEnabled(enabled)
            } catch {
                DispatchQueue.main.async {
                    self.isLaunchAtLogin = LaunchAtLoginService.isEnabled
                }
            }
        } else {
            let helperBundleIdentifier = "com.balajee.Pastry" as CFString
            SMLoginItemSetEnabled(helperBundleIdentifier, enabled)
        }
    }
}
