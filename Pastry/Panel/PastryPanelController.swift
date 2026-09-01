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
        self.isOpaque = false
        self.isMovableByWindowBackground = false
        self.hasShadow = false
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
        PastryPanelController.shared.closePanel()
    }
}

public class PastryPanelController: NSObject, NSWindowDelegate {
    public static let shared = PastryPanelController()
    
    private var panel: PastryPanel?
    private var hostingView: NSHostingView<PastryContainerView>?
    private var viewModel = ClipboardPanelViewModel()
    
    private static let windowWidth: CGFloat = 454
    private static let windowHeight: CGFloat = 486
    private static let cardWidth: CGFloat = 360
    private static let cardHeight: CGFloat = 450
    private static let padding: CGFloat = 18
    private static let buttonAndSpacing: CGFloat = 46 + 12
    
    private override init() {
        super.init()
    }
    
    public func showPanel() {
        // Record focus app before showing
        PasteService.shared.recordActiveApp()
        
        // Reset search field and selection index every time the panel opens
        viewModel.searchText = ""
        viewModel.selectedIndex = 0
        
        let mouseLocation = NSEvent.mouseLocation
        let activeScreen = findActiveScreen(at: mouseLocation)
        let screenFrame = activeScreen.visibleFrame
        
        // Auto-adjust button side: if placing button on right would exceed screen right edge, place on left
        let buttonSide: ScreenshotButtonSide
        if mouseLocation.x + (Self.cardWidth / 2) + Self.buttonAndSpacing + Self.padding > screenFrame.maxX {
            buttonSide = .left
        } else {
            buttonSide = .right
        }
        
        let containerView = PastryContainerView(
            viewModel: viewModel,
            buttonSide: buttonSide,
            onClose: { [weak self] in
                self?.closePanel()
            },
            onScreenshot: { [weak self] in
                self?.startScrollScreenshot()
            },
            onTextShortcuts: {
                TextShortcutsWindowController.shared.toggleWindow()
            }
        )
        
        if panel == nil {
            let rect = NSRect(x: 0, y: 0, width: Self.windowWidth, height: Self.windowHeight)
            let panel = PastryPanel(contentRect: rect)
            panel.delegate = self
            
            let hosting = NSHostingView(rootView: containerView)
            hosting.frame = rect
            hosting.autoresizingMask = [.width, .height]
            panel.contentView = hosting
            self.hostingView = hosting
            
            // Configure the keyboard interceptor
            panel.onKeyDown = { [weak self] event in
                guard let self = self else { return false }
                
                switch event.keyCode {
                case 125: // Arrow Down
                    self.viewModel.moveSelectionDown()
                    return true
                case 126: // Arrow Up
                    self.viewModel.moveSelectionUp()
                    return true
                case 36: // Return / Enter
                    self.viewModel.selectAndPaste {
                        self.closePanel()
                    }
                    return true
                default:
                    return false
                }
            }
            
            self.panel = panel
        } else {
            hostingView?.rootView = containerView
        }
        
        guard let panel = panel else { return }
        
        positionPanel(panel, mouseLocation: mouseLocation, screenFrame: screenFrame, buttonSide: buttonSide)
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let panel = self.panel, panel.isVisible else { return }
            if !panel.isKeyWindow {
                self.closePanel()
            }
        }
    }
    
    /// Closes the panel and starts the scroll screenshot selection flow.
    public func startScrollScreenshot() {
        let screen = panel?.screen
        closePanel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            ScrollScreenshotController.shared.startCapture(on: screen)
        }
    }
    
    private func findActiveScreen(at point: NSPoint) -> NSScreen {
        for screen in NSScreen.screens {
            if NSMouseInRect(point, screen.frame, false) {
                return screen
            }
        }
        return NSScreen.main ?? NSScreen.screens.first!
    }
    
    private func positionPanel(
        _ panel: PastryPanel,
        mouseLocation: NSPoint,
        screenFrame: NSRect,
        buttonSide: ScreenshotButtonSide
    ) {
        // We want the clipboard card (360x450) to center near the mouse cursor
        let cardCenterOffsetX: CGFloat
        if buttonSide == .right {
            // Card is on the left side of container: [padding (18)] [Card (360)] [12] [Button (46)] [padding (18)]
            cardCenterOffsetX = Self.padding + (Self.cardWidth / 2) // 18 + 180 = 198
        } else {
            // Card is on the right side of container: [padding (18)] [Button (46)] [12] [Card (360)] [padding (18)]
            cardCenterOffsetX = Self.padding + Self.buttonAndSpacing + (Self.cardWidth / 2) // 18 + 58 + 180 = 256
        }
        
        let cardCenterOffsetY = Self.padding + (Self.cardHeight / 2) // 18 + 225 = 243
        
        var originX = mouseLocation.x - cardCenterOffsetX
        var originY = mouseLocation.y - cardCenterOffsetY
        
        // Clamp entire window within visible screen bounds
        originX = max(screenFrame.minX, min(originX, screenFrame.maxX - Self.windowWidth))
        originY = max(screenFrame.minY, min(originY, screenFrame.maxY - Self.windowHeight))
        
        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }
}
