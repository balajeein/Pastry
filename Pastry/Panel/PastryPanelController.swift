import Cocoa
import SwiftUI

public class PastryPanel: NSPanel {
    public var onKeyDown: ((NSEvent) -> Bool)?
    
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.backgroundColor = .clear
        self.isMovableByWindowBackground = false
        self.hasShadow = true
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
    
    public override func keyDown(with event: NSEvent) {
        // Intercept keys for list navigation/actions
        if onKeyDown?(event) == true {
            return
        }
        super.keyDown(with: event)
    }
    
    public override func cancelOperation(_ sender: Any?) {
        // Dismiss on Escape key
        self.close()
    }
}

public class PastryPanelController: NSObject, NSWindowDelegate {
    public static let shared = PastryPanelController()
    
    private var panel: PastryPanel?
    private var viewModel = ClipboardPanelViewModel()
    
    private override init() {
        super.init()
    }
    
    public func showPanel() {
        // Record focus app before showing
        PasteService.shared.recordActiveApp()
        
        // Reset search field and selection index every time the panel opens
        viewModel.searchText = ""
        viewModel.selectedIndex = 0
        
        if panel == nil {
            let width: CGFloat = 360
            let height: CGFloat = 450
            let rect = NSRect(x: 0, y: 0, width: width, height: height)
            
            let panel = PastryPanel(contentRect: rect)
            panel.delegate = self
            
            // HUD visual effect background
            let visualEffectView = NSVisualEffectView(frame: rect)
            visualEffectView.material = .hudWindow
            visualEffectView.state = .active
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.autoresizingMask = [.width, .height]
            visualEffectView.wantsLayer = true
            visualEffectView.layer?.cornerRadius = 16
            visualEffectView.layer?.masksToBounds = true
            
            // Embed ClipboardPanelView using our shared viewModel
            let contentView = ClipboardPanelView(viewModel: viewModel) { [weak self] in
                self?.closePanel()
            }
            let hostingView = NSHostingView(rootView: contentView)
            hostingView.frame = rect
            hostingView.autoresizingMask = [.width, .height]
            
            visualEffectView.addSubview(hostingView)
            panel.contentView = visualEffectView
            
            // Configure the keyboard interceptor
            panel.onKeyDown = { [weak self, weak panel] event in
                guard let self = self, let panel = panel else { return false }
                
                switch event.keyCode {
                case 125: // Arrow Down
                    self.viewModel.moveSelectionDown()
                    return true
                case 126: // Arrow Up
                    self.viewModel.moveSelectionUp()
                    return true
                case 36: // Return / Enter
                    self.viewModel.selectAndPaste {
                        panel.close()
                    }
                    return true
                default:
                    return false
                }
            }
            
            self.panel = panel
        }
        
        guard let panel = panel else { return }
        
        positionPanel(panel)
        panel.makeKeyAndOrderFront(nil)
        
        // Activate our process to handle keystrokes
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func closePanel() {
        panel?.close()
    }
    
    public func togglePanel() {
        if let panel = panel, panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }
    
    public func windowDidResignKey(_ notification: Notification) {
        // Automatically close when focus is lost
        closePanel()
    }
    
    /// Closes the panel and starts the scroll screenshot selection flow.
    public func startScrollScreenshot() {
        let screen = panel?.screen
        closePanel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            ScrollScreenshotController.shared.startCapture(on: screen)
        }
    }
    
    private func positionPanel(_ panel: PastryPanel) {
        let mouseLocation = NSEvent.mouseLocation
        
        var activeScreen = NSScreen.main ?? NSScreen.screens.first!
        for screen in NSScreen.screens {
            if NSMouseInRect(mouseLocation, screen.frame, false) {
                activeScreen = screen
                break
            }
        }
        
        let screenFrame = activeScreen.visibleFrame
        let panelSize = panel.frame.size
        
        var x = mouseLocation.x - panelSize.width / 2
        var y = mouseLocation.y - panelSize.height / 2
        
        x = max(screenFrame.minX + 12, min(x, screenFrame.maxX - panelSize.width - 12))
        y = max(screenFrame.minY + 12, min(y, screenFrame.maxY - panelSize.height - 12))
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
