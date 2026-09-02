import Cocoa
import Foundation

public class AppDelegate: NSObject, NSApplicationDelegate {
    
    public override init() {
        super.init()
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // 0. Setup standard Main Menu (enables ⌘C, ⌘V, ⌘X, ⌘A, ⌘Z in text fields across all panels)
        setupStandardMainMenu()
        
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
        
        // 4. Begin monitoring Text Shortcuts (⌥ + Space)
        TextShortcutStore.shared.load()
        TextShortcutMonitor.shared.startMonitoring()
        
        // 5. Initialize Sparkle Automatic Updater
        UpdaterController.shared.start()
        
        // 6. Handle first launch behavior
        checkFirstLaunch()
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        // Stop tracking
        ClipboardManager.shared.stopMonitoring()
        TextShortcutMonitor.shared.stopMonitoring()
        
        // Cleanup clipboard if configured
        if SettingsManager.shared.clearHistoryOnQuit {
            ClipboardStore.shared.clearHistory()
        }
    }
    
    private func setupStandardMainMenu() {
        let mainMenu = NSMenu()
        
        // Application Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Pastry", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdatesPressed), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Pastry", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Edit Menu (Standard macOS responder routing for Cut, Copy, Paste, Select All, Undo, Redo)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    @objc private func checkForUpdatesPressed() {
        UpdaterController.shared.checkForUpdates()
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
