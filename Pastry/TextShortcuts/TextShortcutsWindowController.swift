import Cocoa
import SwiftUI

public class TextShortcutsPanel: NSPanel {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
    
    public override func cancelOperation(_ sender: Any?) {
        TextShortcutsWindowController.shared.closeWindow()
    }
    
    /// Ensures ⌘V, ⌘C, ⌘X, ⌘A, ⌘Z are routed directly to the active first responder text field/editor.
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
            switch chars {
            case "v":
                if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) { return true }
            case "c":
                if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) { return true }
            case "x":
                if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) { return true }
            case "a":
                if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self) { return true }
            case "z":
                let selector = event.modifierFlags.contains(.shift) ? Selector(("redo:")) : Selector(("undo:"))
                if NSApp.sendAction(selector, to: nil, from: self) { return true }
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// Controls the floating "Text Shortcuts" management window.
public class TextShortcutsWindowController: NSObject, NSWindowDelegate {
    public static let shared = TextShortcutsWindowController()
    
    private var window: TextShortcutsPanel?
    private var outsideClickGlobalMonitor: Any?
    private var outsideClickLocalMonitor: Any?
    
    private override init() {
        super.init()
    }
    
    public func showWindow() {
        if window == nil {
            let width: CGFloat = 420
            let height: CGFloat = 390
            let rect = NSRect(x: 0, y: 0, width: width, height: height)
            
            let panel = TextShortcutsPanel(
                contentRect: rect,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.delegate = self
            
            let view = TextShortcutsView { [weak self] in
                self?.closeWindow()
            }
            let hosting = NSHostingView(rootView: view)
            hosting.frame = rect
            hosting.autoresizingMask = [.width, .height]
            panel.contentView = hosting
            
            self.window = panel
        }
        
        guard let panel = window else { return }
        
        // Center the window on the active screen
        let mouseLocation = NSEvent.mouseLocation
        var activeScreen = NSScreen.main ?? NSScreen.screens.first!
        for screen in NSScreen.screens {
            if NSMouseInRect(mouseLocation, screen.frame, false) {
                activeScreen = screen
                break
            }
        }
        
        let screenFrame = activeScreen.visibleFrame
        let x = screenFrame.midX - panel.frame.width / 2
        let y = screenFrame.midY - panel.frame.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        installOutsideClickMonitors()
    }
    
    public func closeWindow() {
        removeOutsideClickMonitors()
        window?.close()
    }
    
    public func toggleWindow() {
        if let win = window, win.isVisible {
            closeWindow()
        } else {
            showWindow()
        }
    }
    
    public func windowDidResignKey(_ notification: Notification) {
        // Automatically close when focus is lost (unless a modal sheet is attached)
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let panel = self.window, panel.isVisible else { return }
            if panel.attachedSheet != nil { return }
            if !panel.isKeyWindow {
                self.closeWindow()
            }
        }
    }
    
    // MARK: - Outside Click Dismissal
    
    private func installOutsideClickMonitors() {
        removeOutsideClickMonitors()
        
        // Global monitor: handles clicks outside the app in other apps / desktop
        outsideClickGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let win = self.window, win.isVisible else { return }
            if win.attachedSheet != nil { return }
            
            let mouseLocation = NSEvent.mouseLocation
            if !NSMouseInRect(mouseLocation, win.frame, false) {
                DispatchQueue.main.async {
                    self.closeWindow()
                }
            }
        }
        
        // Local monitor: handles clicks in other Pastry panels / windows
        outsideClickLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let win = self.window, win.isVisible else { return event }
            if win.attachedSheet != nil { return event }
            
            if let eventWindow = event.window, eventWindow != win {
                DispatchQueue.main.async {
                    self.closeWindow()
                }
            }
            return event
        }
    }
    
    private func removeOutsideClickMonitors() {
        if let monitor = outsideClickGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickGlobalMonitor = nil
        }
        if let monitor = outsideClickLocalMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickLocalMonitor = nil
        }
    }
}
