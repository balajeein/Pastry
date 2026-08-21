import Cocoa
import Foundation

public class AppDelegate: NSObject, NSApplicationDelegate {
    
    public override init() {
        super.init()
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Initialize Settings and register Hotkey
        let settings = SettingsManager.shared
        GlobalHotkeyManager.shared.onTrigger = {
            PastryPanelController.shared.togglePanel()
        }
        settings.registerCurrentHotkey()
        
        // 2. Setup the Status Bar Menu Bar Item
        MenuBarController.shared.setupMenuBar()
        
        // 3. Begin tracking Clipboard alterations
        ClipboardManager.shared.startMonitoring()
        
        // 4. Handle first launch behavior
        checkFirstLaunch()
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        // Stop tracking
        ClipboardManager.shared.stopMonitoring()
        
        // Cleanup clipboard if configured
        if SettingsManager.shared.clearHistoryOnQuit {
            ClipboardStore.shared.clearHistory()
        }
    }
    
    private func checkFirstLaunch() {
        let launchedBeforeKey = "hasLaunchedBefore"
        if !UserDefaults.standard.bool(forKey: launchedBeforeKey) {
            UserDefaults.standard.set(true, forKey: launchedBeforeKey)
            
            // Show welcome info alert natively
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let alert = NSAlert()
                alert.messageText = "Welcome to Pastry!"
                alert.informativeText = "Pastry is running silently in your menu bar.\n\nPress ⌘⇧V at any time to open your clipboard history.\n\nNote: Pastry needs Accessibility permission to paste clipboard items into the application you're currently using."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Get Started")
                alert.addButton(withTitle: "Open Settings")
                
                let response = alert.runModal()
                if response == .alertSecondButtonReturn {
                    MenuBarController.shared.settingsPressed()
                }
            }
        }
    }
}
