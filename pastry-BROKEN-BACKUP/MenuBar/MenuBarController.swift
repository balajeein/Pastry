import Cocoa
import SwiftUI

public class MenuBarController: NSObject, NSMenuDelegate {
    public static let shared = MenuBarController()
    
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var settingsWindow: NSWindow?
    
    private override init() {
        super.init()
    }
    
    public func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Pastry") {
                image.isTemplate = true
                button.image = image
            }
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self
        
        let titleItem = NSMenuItem(title: "Pastry", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        let openItem = NSMenuItem(title: "Open Clipboard", action: #selector(openClipboardPressed), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let pauseItem = NSMenuItem(title: "Pause History", action: #selector(pauseHistoryPressed), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)
        
        let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistoryPressed), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(settingsPressed), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Pastry", action: #selector(quitPressed), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        self.menu = menu
    }
    
    public func menuWillOpen(_ menu: NSMenu) {
        // Toggle the checkmark state for "Pause History"
        if let pauseItem = menu.items.first(where: { $0.action == #selector(pauseHistoryPressed) }) {
            pauseItem.state = SettingsManager.shared.isHistoryPaused ? .on : .off
        }
    }
    
    @objc private func openClipboardPressed() {
        PastryPanelController.shared.showPanel()
    }
    
    @objc private func pauseHistoryPressed() {
        SettingsManager.shared.isHistoryPaused.toggle()
    }
    
    @objc private func clearHistoryPressed() {
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "This will delete all cached text, images, and other formats from local disk. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            ClipboardStore.shared.clearHistory()
        }
    }
    
    @objc public func settingsPressed() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 280),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Pastry Settings"
            window.center()
            window.isReleasedWhenClosed = false
            
            let hostingController = NSHostingController(rootView: SettingsView())
            window.contentViewController = hostingController
            
            self.settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func quitPressed() {
        if SettingsManager.shared.clearHistoryOnQuit {
            ClipboardStore.shared.clearHistory()
        }
        NSApp.terminate(nil)
    }
}
