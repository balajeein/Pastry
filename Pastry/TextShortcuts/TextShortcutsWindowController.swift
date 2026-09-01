import Cocoa
import SwiftUI

public class TextShortcutsPanel: NSPanel {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
    
    public override func cancelOperation(_ sender: Any?) {
        TextShortcutsWindowController.shared.closeWindow()
    }
}

/// Controls the floating "Text Shortcuts" management window.
public class TextShortcutsWindowController: NSObject, NSWindowDelegate {
    public static let shared = TextShortcutsWindowController()
    
    private var window: TextShortcutsPanel?
    
    private override init() {
        super.init()
    }
    
    public func showWindow() {
        if window == nil {
            let width: CGFloat = 400
            let height: CGFloat = 380
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
    }
    
    public func closeWindow() {
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
        // Keep window open or dismiss when focus changes if desired
    }
}
