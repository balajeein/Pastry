import Cocoa
import SwiftUI
import Combine

public class MenuBarController: NSObject, NSMenuDelegate {
    public static let shared = MenuBarController()
    
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var settingsWindow: NSWindow?
    private var openClipboardMenuItem: NSMenuItem?
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
        setupObservers()
    }
    
    private func setupObservers() {
        SettingsManager.shared.$hotKeyCode
            .combineLatest(SettingsManager.shared.$hotKeyModifiers)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateOpenClipboardShortcut()
            }
            .store(in: &cancellables)
    }
    
    public func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = menuBarIcon()
        }
        
        setupMenu()
    }
    
    private func menuBarIcon() -> NSImage {
        // 1. Try loading named image from App Bundle (handles @2x automatically)
        if let image = NSImage(named: NSImage.Name("MenuBarIcon")) {
            image.size = NSSize(width: 22, height: 18)
            image.isTemplate = true
            return image
        }
        
        // 2. Try loading direct resource file from Bundle
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 22, height: 18)
            image.isTemplate = true
            return image
        }
        
        // 3. Fallback embedded Retina template data
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAACwAAAAkCAYAAADy19hsAAAEfklEQVR4nO2YaYiVVRjHf3eWsnG0RS2ziPY9bZIywjaxIPwQ+cECKyiihIoKiVYqEEQoAiUxkiKaLxL0oVBCiRYiWmghhpaJoLJIh8hp2syZZm4c+J14eHnfuffWTEPgHw733HPPe87/+Z/zLPeF/fh/YxrwMXCd32v/dsE2JgeZ2CnAfOCowviUo00yNftZiM3AXmCe39uZYoyn2DlAHfgEOKFAdkqUzpvOBFYDbwBvAXdK8GsJf+/nD8ADwIypIJ03S/fzR2AIeNK2V4KjwEoJngzc529p7pUla006ulXtZaNBRup/ATxf8kwiv0GDeoPak+X8fy+eVFkFjABdYfx2YA3wiqSeUt0iqQuBAduiyVQ7R4KEl4Ad9rNDPS3RTcC1wOtejZ6Csajuc86/J+wxYWpH61e70ebCJscC3wFbwtztOmNcI661wrVeBWZPFOm8wBzgTeA31f2yEH8TDlPRTr+vMVKUoRYMTRnxF2BxiVEtIT94gUQ/BI7Q6ZIyd5XMzeg2KqwvGB6RxzqAJ1zztn9COk5e5ULrCwngKsfXArPCeKeOtRP4zFg9HoE4frVrbmiFcC1Yv8kFVhZ+z3MuMUmMmNXe1/vTM88Ch7SwZ1Z7gSfzcCtkp+kwKdgvDAZUGXY+cKsOudxrU4Vi3VGm5M2K0BQOAt7T4+c18Nzxjq2t0MabW/NaLTKFp1N6oTipo2KTF4G5wFnAoGNjFRvVg1qZUE7NYxXrz7LeOMOIssAEczjwJ/ABsCdEmnEJJ6+/FDi6hGwxjtZDG61Q7HjgTK9VquBONN4mYrtM4+9ah3wOfCXZx4DLmiH8kIXKgBEhEqkXPgmx97hArEfFZmvsLqPFa8DjkvxGxyquFa/l780Q3umGBwDDYbxdjz/Go4zE5khsQGIps200anwL/FRBKq6dnr8BuF+1F6p8Q1yh1YM6Xmr9lpHJa/cBuy1wUvy9xjt4cBOk2kP83q5Rhzo2133XAX32T2+G8ApVXgrc7fVIiWOZyjaKq9n5rtfQZPBF4fd1kkl39CPgHccvNoQmHOlVTNesIZaagmONW8RyN8uncK7jWcHLQ9p+1P6DHnXd6JMrtrqZsMd9azpq3UjSEB1ancjcESoo9Pot4eiWWVKOeKRZ3W1muShCn+XmaQXj+l1ro330i7rEm0KvD/d7Z/tUcp9V1UmF+W+HUhPveKqH2yr+KdcKRdVuK7+zA+HRZhVGh0h3LOE84BbVzqUfgUzNjbLqvYarXAxFcrEf0V6YM9/18vuMhtjmEVWhVtJf4pGnfyKnlsyLqIVWdgLPWFA1Xcj3qjKmx/bQyl6aVNW5tRZr2i4L/rpVYNNY4kPpaCYSbUafXEss9r3bWk81vwZIuYAyY8usr0k2ef+NwCPAVrNVpxt22aYbmrr9nGki6DaRzAj96bauEDL/MBqlNP2pp7rVlJx5NCQccRNwb+Hyj1m4DBvOho2fSZ1fgZ/9TG3INqjBQxY2exwbknSVaKU/NIN0hAdKMJMckXhV8dIK4l2vKmP3g/8CfwFHlBOLbA7FuwAAAABJRU5ErkJggg=="

        if let data = Data(base64Encoded: base64), let image = NSImage(data: data) {
            image.size = NSSize(width: 22, height: 18)
            image.isTemplate = true
            return image
        }
        
        // 4. Fallback to system symbol if all else fails
        let image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Pastry") ?? NSImage()
        image.isTemplate = true
        return image
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self
        
        let titleItem = NSMenuItem(title: "Pastry", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        let openItem = NSMenuItem(title: "Open Clipboard", action: #selector(openClipboardPressed), keyEquivalent: "")
        openItem.target = self
        self.openClipboardMenuItem = openItem
        menu.addItem(openItem)
        updateOpenClipboardShortcut()
        
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
        
        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdatesPressed), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)
        
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
        updateOpenClipboardShortcut()
    }
    
    public func updateOpenClipboardShortcut() {
        guard let openItem = openClipboardMenuItem ?? menu?.items.first(where: { $0.action == #selector(openClipboardPressed) }) else {
            return
        }
        
        let keyCode = SettingsManager.shared.hotKeyCode
        let modifiers = SettingsManager.shared.hotKeyModifiers
        
        let keyEquivalent = GlobalHotkeyManager.getKeyEquivalent(keyCode: keyCode)
        if keyEquivalent.isEmpty {
            openItem.keyEquivalent = ""
            openItem.keyEquivalentModifierMask = []
        } else {
            openItem.keyEquivalent = keyEquivalent
            openItem.keyEquivalentModifierMask = GlobalHotkeyManager.keyEquivalentModifierMask(from: modifiers)
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
    
    @objc private func checkForUpdatesPressed() {
        UpdaterController.shared.checkForUpdates()
    }
    
    @objc private func quitPressed() {
        if SettingsManager.shared.clearHistoryOnQuit {
            ClipboardStore.shared.clearHistory()
        }
        NSApp.terminate(nil)
    }
}
