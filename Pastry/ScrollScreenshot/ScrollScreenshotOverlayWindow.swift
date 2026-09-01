import Cocoa
import CoreGraphics

// MARK: - Camera Cursor Extension

public extension NSCursor {
    /// Custom high-visibility camera cursor used during scroll screenshot capture.
    static let cameraCursor: NSCursor = {
        let size = NSSize(width: 32, height: 32)
        let image = NSImage(size: size)
        image.lockFocus()
        
        let circleRect = NSRect(x: 3, y: 3, width: 26, height: 26)
        let circlePath = NSBezierPath(ovalIn: circleRect)
        
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
        shadow.shadowBlurRadius = 3
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.set()
        
        NSColor(calibratedWhite: 0.15, alpha: 0.9).setFill()
        circlePath.fill()
        NSGraphicsContext.restoreGraphicsState()
        
        NSColor.white.withAlphaComponent(0.35).setStroke()
        circlePath.lineWidth = 1.0
        circlePath.stroke()
        
        if #available(macOS 11.0, *),
           let sfImage = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .bold)
            if let configured = sfImage.withSymbolConfiguration(config) {
                let iconRect = NSRect(x: 7, y: 7, width: 18, height: 18)
                configured.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            }
        }
        
        image.unlockFocus()
        return NSCursor(image: image, hotSpot: NSPoint(x: 16, y: 16))
    }()
}

// MARK: - Overlay Content View

/// Custom NSView that handles the selection rectangle, resize handles, and overlay drawing.
class ScrollScreenshotOverlayView: NSView {
    
    // Selection rectangle in view coordinates (bottom-left origin)
    var selectionRect: NSRect = NSRect(x: 200, y: 200, width: 500, height: 400) {
        didSet { needsDisplay = true }
    }
    
    /// Whether the selection is locked (capture in progress)
    var isLocked: Bool = false {
        didSet { needsDisplay = true }
    }
    
    /// Whether a capture is currently running
    var isCapturing: Bool = false {
        didSet {
            window?.invalidateCursorRects(for: self)
            needsDisplay = true
        }
    }
    
    /// Number of frames captured so far
    var frameCount: Int = 0 {
        didSet { needsDisplay = true }
    }
    
    /// Selected scroll direction (default: vertical)
    var scrollDirection: ImageStitcher.StitchDirection = .vertical {
        didSet { needsDisplay = true }
    }
    
    /// Callbacks
    var onCapture: (() -> Void)?
    var onCancel: (() -> Void)?
    
    // Drag state
    private enum DragMode {
        case none
        case move
        case resizeTopLeft, resizeTop, resizeTopRight
        case resizeLeft, resizeRight
        case resizeBottomLeft, resizeBottom, resizeBottomRight
    }
    
    private var dragMode: DragMode = .none
    private var dragStartPoint: NSPoint = .zero
    private var dragStartRect: NSRect = .zero
    
    private let handleSize: CGFloat = 8
    private let minSelectionSize: CGFloat = 80
    
    // HUD Control Bar Layout Rects
    private var hudBarRect: NSRect = .zero
    private var closeButtonRect: NSRect = .zero
    private var optionsButtonRect: NSRect = .zero
    private var captureButtonRect: NSRect = .zero
    
    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let viewBounds = bounds
        
        if !isCapturing {
            // Semi-transparent dimmed overlay outside selection before capture starts
            context.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
            
            let topRect = NSRect(x: 0, y: selectionRect.maxY, width: viewBounds.width, height: viewBounds.height - selectionRect.maxY)
            context.fill(topRect)
            let bottomRect = NSRect(x: 0, y: 0, width: viewBounds.width, height: selectionRect.minY)
            context.fill(bottomRect)
            let leftRect = NSRect(x: 0, y: selectionRect.minY, width: selectionRect.minX, height: selectionRect.height)
            context.fill(leftRect)
            let rightRect = NSRect(x: selectionRect.maxX, y: selectionRect.minY, width: viewBounds.width - selectionRect.maxX, height: selectionRect.height)
            context.fill(rightRect)
        }
        
        // Draw selection border: clean white dashed rectangle (always white)
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [5, 4])
        context.stroke(selectionRect)
        context.setLineDash(phase: 0, lengths: [])
        
        if !isLocked && !isCapturing {
            drawResizeHandles(context: context)
            drawHUDControlBar(context: context)
        }
    }
    
    private func drawResizeHandles(context: CGContext) {
        let handleColor = NSColor.white.cgColor
        let handles = getHandleRects()
        
        context.setFillColor(handleColor)
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1.0)
        
        for handleRect in handles {
            let path = CGPath(ellipseIn: handleRect, transform: nil)
            context.addPath(path)
            context.drawPath(using: .fillStroke)
        }
    }
    
    private func getHandleRects() -> [NSRect] {
        let s = handleSize
        let r = selectionRect
        return [
            NSRect(x: r.minX - s/2, y: r.maxY - s/2, width: s, height: s),   // top-left
            NSRect(x: r.midX - s/2, y: r.maxY - s/2, width: s, height: s),   // top-center
            NSRect(x: r.maxX - s/2, y: r.maxY - s/2, width: s, height: s),   // top-right
            NSRect(x: r.minX - s/2, y: r.midY - s/2, width: s, height: s),   // left
            NSRect(x: r.maxX - s/2, y: r.midY - s/2, width: s, height: s),   // right
            NSRect(x: r.minX - s/2, y: r.minY - s/2, width: s, height: s),   // bottom-left
            NSRect(x: r.midX - s/2, y: r.minY - s/2, width: s, height: s),   // bottom-center
            NSRect(x: r.maxX - s/2, y: r.minY - s/2, width: s, height: s),   // bottom-right
        ]
    }
    
    // MARK: - Native macOS HUD Control Bar (Matching Provided Design)
    
    private func drawHUDControlBar(context: CGContext) {
        let barWidth: CGFloat = 260
        let barHeight: CGFloat = 46
        let cornerRadius: CGFloat = 16
        
        var barX = selectionRect.midX - barWidth / 2
        var barY = selectionRect.minY - barHeight - 16
        
        // Ensure bar stays visible inside the window
        if barY < 20 {
            barY = selectionRect.maxY + 16
        }
        if barY + barHeight > bounds.height - 20 {
            barY = bounds.height - barHeight - 20
        }
        if barX < 20 { barX = 20 }
        if barX + barWidth > bounds.width - 20 { barX = bounds.width - barWidth - 20 }
        
        hudBarRect = NSRect(x: barX, y: barY, width: barWidth, height: barHeight)
        
        // 1. Bar Shadow & Background
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -4), blur: 14, color: NSColor.black.withAlphaComponent(0.55).cgColor)
        
        let barPath = CGPath(roundedRect: hudBarRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.setFillColor(NSColor(calibratedWhite: 0.14, alpha: 0.92).cgColor)
        context.addPath(barPath)
        context.fillPath()
        context.restoreGState()
        
        // Subtle top glass highlight border
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.18).cgColor)
        context.setLineWidth(1.0)
        context.addPath(barPath)
        context.strokePath()
        
        // 2. Button 1: Close (x) circle button on the left
        let closeBtnSize: CGFloat = 22
        let closeBtnX = barX + 14
        let closeBtnY = barY + (barHeight - closeBtnSize) / 2
        closeButtonRect = NSRect(x: closeBtnX, y: closeBtnY, width: closeBtnSize, height: closeBtnSize)
        
        let closeCirclePath = CGPath(ellipseIn: closeButtonRect, transform: nil)
        context.setFillColor(NSColor.white.withAlphaComponent(0.16).cgColor)
        context.addPath(closeCirclePath)
        context.fillPath()
        
        if #available(macOS 11.0, *),
           let xmarkImg = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            if let configured = xmarkImg.withSymbolConfiguration(config) {
                let iconRect = NSRect(x: closeBtnX + 6, y: closeBtnY + 6, width: 10, height: 10)
                configured.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 0.85)
            }
        }
        
        // 3. Vertical Separator
        let sepX = closeButtonRect.maxX + 14
        let sepY = barY + 12
        let sepHeight: CGFloat = barHeight - 24
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.16).cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: sepX, y: sepY))
        context.addLine(to: CGPoint(x: sepX, y: sepY + sepHeight))
        context.strokePath()
        
        // 4. Button 2: Options ⌵ dropdown button
        let optionsX = sepX + 12
        let optionsWidth: CGFloat = 88
        optionsButtonRect = NSRect(x: optionsX, y: barY + 6, width: optionsWidth, height: barHeight - 12)
        
        let dirLabel = scrollDirection == .vertical ? "Options ⌵" : "Options (X) ⌵"
        let optionsText = dirLabel as NSString
        let optionsAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.9)
        ]
        let optSize = optionsText.size(withAttributes: optionsAttrs)
        let optPoint = NSPoint(
            x: optionsButtonRect.midX - optSize.width / 2,
            y: optionsButtonRect.midY - optSize.height / 2
        )
        optionsText.draw(at: optPoint, withAttributes: optionsAttrs)
        
        // 5. Button 3: Capture blue pill button on the right
        let capWidth: CGFloat = 82
        let capHeight: CGFloat = 32
        let capX = barX + barWidth - capWidth - 8
        let capY = barY + (barHeight - capHeight) / 2
        captureButtonRect = NSRect(x: capX, y: capY, width: capWidth, height: capHeight)
        
        let capPath = CGPath(roundedRect: captureButtonRect, cornerWidth: 9, cornerHeight: 9, transform: nil)
        // Vibrant system blue
        context.setFillColor(NSColor(calibratedRed: 0.0, green: 0.58, blue: 1.0, alpha: 1.0).cgColor)
        context.addPath(capPath)
        context.fillPath()
        
        let capText = "Capture" as NSString
        let capAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let capSize = capText.size(withAttributes: capAttrs)
        let capPoint = NSPoint(
            x: captureButtonRect.midX - capSize.width / 2,
            y: captureButtonRect.midY - capSize.height / 2
        )
        capText.draw(at: capPoint, withAttributes: capAttrs)
    }
    
    // MARK: - Options Menu
    
    private func showOptionsMenu(at event: NSEvent) {
        let menu = NSMenu(title: "Scroll Options")
        
        let verticalItem = NSMenuItem(
            title: "Vertical Scroll (Y-Axis)",
            action: #selector(selectVerticalDirection),
            keyEquivalent: ""
        )
        verticalItem.target = self
        verticalItem.state = scrollDirection == .vertical ? .on : .off
        menu.addItem(verticalItem)
        
        let horizontalItem = NSMenuItem(
            title: "Horizontal Scroll (X-Axis)",
            action: #selector(selectHorizontalDirection),
            keyEquivalent: ""
        )
        horizontalItem.target = self
        horizontalItem.state = scrollDirection == .horizontal ? .on : .off
        menu.addItem(horizontalItem)
        
        let point = NSPoint(x: optionsButtonRect.minX, y: optionsButtonRect.minY)
        menu.popUp(positioning: nil, at: point, in: self)
    }
    
    @objc private func selectVerticalDirection() {
        scrollDirection = .vertical
        ScrollScreenshotController.shared.scrollDirection = .vertical
        needsDisplay = true
    }
    
    @objc private func selectHorizontalDirection() {
        scrollDirection = .horizontal
        ScrollScreenshotController.shared.scrollDirection = .horizontal
        needsDisplay = true
    }
    
    // MARK: - Mouse Handling
    
    override func mouseDown(with event: NSEvent) {
        guard !isLocked && !isCapturing else { return }
        
        let point = convert(event.locationInWindow, from: nil)
        
        // 1. Close (X) button
        if closeButtonRect.contains(point) {
            onCancel?()
            return
        }
        
        // 2. Options button
        if optionsButtonRect.contains(point) {
            showOptionsMenu(at: event)
            return
        }
        
        // 3. Capture button
        if captureButtonRect.contains(point) {
            onCapture?()
            return
        }
        
        // If clicking anywhere inside HUD bar background, don't drag selection
        if hudBarRect.contains(point) {
            return
        }
        
        // 4. Resize handles
        let handles = getHandleRects()
        let modes: [DragMode] = [
            .resizeTopLeft, .resizeTop, .resizeTopRight,
            .resizeLeft, .resizeRight,
            .resizeBottomLeft, .resizeBottom, .resizeBottomRight
        ]
        
        let expandedHandleSize: CGFloat = handleSize + 8
        for (i, handleRect) in handles.enumerated() {
            let expanded = handleRect.insetBy(dx: -(expandedHandleSize - handleSize)/2, dy: -(expandedHandleSize - handleSize)/2)
            if expanded.contains(point) {
                dragMode = modes[i]
                dragStartPoint = point
                dragStartRect = selectionRect
                return
            }
        }
        
        // 5. Move selection
        if selectionRect.contains(point) {
            dragMode = .move
            dragStartPoint = point
            dragStartRect = selectionRect
            return
        }
        
        // Click outside everything before capture: cancel
        onCancel?()
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard !isLocked && !isCapturing else { return }
        let point = convert(event.locationInWindow, from: nil)
        let dx = point.x - dragStartPoint.x
        let dy = point.y - dragStartPoint.y
        
        switch dragMode {
        case .move:
            var newRect = dragStartRect.offsetBy(dx: dx, dy: dy)
            newRect.origin.x = max(0, min(newRect.origin.x, bounds.width - newRect.width))
            newRect.origin.y = max(0, min(newRect.origin.y, bounds.height - newRect.height))
            selectionRect = newRect
            
        case .resizeTopLeft:
            let newX = min(dragStartRect.maxX - minSelectionSize, dragStartRect.minX + dx)
            let newMaxY = max(dragStartRect.minY + minSelectionSize, dragStartRect.maxY + dy)
            selectionRect = NSRect(x: newX, y: dragStartRect.minY, width: dragStartRect.maxX - newX, height: newMaxY - dragStartRect.minY)
            
        case .resizeTop:
            let newMaxY = max(dragStartRect.minY + minSelectionSize, dragStartRect.maxY + dy)
            selectionRect = NSRect(x: dragStartRect.minX, y: dragStartRect.minY, width: dragStartRect.width, height: newMaxY - dragStartRect.minY)
            
        case .resizeTopRight:
            let newMaxX = max(dragStartRect.minX + minSelectionSize, dragStartRect.maxX + dx)
            let newMaxY = max(dragStartRect.minY + minSelectionSize, dragStartRect.maxY + dy)
            selectionRect = NSRect(x: dragStartRect.minX, y: dragStartRect.minY, width: newMaxX - dragStartRect.minX, height: newMaxY - dragStartRect.minY)
            
        case .resizeLeft:
            let newX = min(dragStartRect.maxX - minSelectionSize, dragStartRect.minX + dx)
            selectionRect = NSRect(x: newX, y: dragStartRect.minY, width: dragStartRect.maxX - newX, height: dragStartRect.height)
            
        case .resizeRight:
            let newMaxX = max(dragStartRect.minX + minSelectionSize, dragStartRect.maxX + dx)
            selectionRect = NSRect(x: dragStartRect.minX, y: dragStartRect.minY, width: newMaxX - dragStartRect.minX, height: dragStartRect.height)
            
        case .resizeBottomLeft:
            let newX = min(dragStartRect.maxX - minSelectionSize, dragStartRect.minX + dx)
            let newY = min(dragStartRect.maxY - minSelectionSize, dragStartRect.minY + dy)
            selectionRect = NSRect(x: newX, y: newY, width: dragStartRect.maxX - newX, height: dragStartRect.maxY - newY)
            
        case .resizeBottom:
            let newY = min(dragStartRect.maxY - minSelectionSize, dragStartRect.minY + dy)
            selectionRect = NSRect(x: dragStartRect.minX, y: newY, width: dragStartRect.width, height: dragStartRect.maxY - newY)
            
        case .resizeBottomRight:
            let newMaxX = max(dragStartRect.minX + minSelectionSize, dragStartRect.maxX + dx)
            let newY = min(dragStartRect.maxY - minSelectionSize, dragStartRect.minY + dy)
            selectionRect = NSRect(x: dragStartRect.minX, y: newY, width: newMaxX - dragStartRect.minX, height: dragStartRect.maxY - newY)
            
        case .none:
            break
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        dragMode = .none
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }
    
    override func resetCursorRects() {
        super.resetCursorRects()
        
        if isCapturing {
            addCursorRect(bounds, cursor: .cameraCursor)
            return
        }
        
        guard !isLocked else { return }
        
        let handles = getHandleRects()
        let cursors: [NSCursor] = [
            .crosshair,
            .resizeUpDown,
            .crosshair,
            .resizeLeftRight,
            .resizeLeftRight,
            .crosshair,
            .resizeUpDown,
            .crosshair,
        ]
        
        for (i, rect) in handles.enumerated() {
            let expanded = rect.insetBy(dx: -4, dy: -4)
            addCursorRect(expanded, cursor: cursors[i])
        }
        
        addCursorRect(selectionRect, cursor: .openHand)
    }
}

// MARK: - Overlay Window

/// A full-screen transparent window used for the scroll screenshot selection overlay.
public class ScrollScreenshotOverlayWindow: NSWindow {
    
    var overlayView: ScrollScreenshotOverlayView!
    
    /// Creates a full-screen overlay window on the given screen.
    public init(screen: NSScreen) {
        let screenFrame = screen.frame
        
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false
        
        // Create the overlay view
        overlayView = ScrollScreenshotOverlayView(frame: NSRect(origin: .zero, size: screenFrame.size))
        overlayView.autoresizingMask = [.width, .height]
        
        // Center the default selection on the screen
        let selWidth: CGFloat = min(500, screenFrame.width * 0.5)
        let selHeight: CGFloat = min(400, screenFrame.height * 0.5)
        let selX = (screenFrame.width - selWidth) / 2
        let selY = (screenFrame.height - selHeight) / 2
        overlayView.selectionRect = NSRect(x: selX, y: selY, width: selWidth, height: selHeight)
        
        self.contentView = overlayView
        self.setFrame(screenFrame, display: true)
    }
    
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
    
    /// Returns the selection rectangle in CG screen coordinates (top-left origin).
    public func selectionInScreenCoordinates() -> CGRect {
        let viewRect = overlayView.selectionRect
        guard let screen = self.screen else {
            return CGRect(x: viewRect.minX, y: viewRect.minY, width: viewRect.width, height: viewRect.height)
        }
        
        let screenFrame = screen.frame
        // Convert from view coordinates (bottom-left) to screen coordinates (top-left for CGWindowListCreateImage)
        let cgY = screenFrame.height - viewRect.maxY + screenFrame.minY
        let cgX = viewRect.minX + screenFrame.minX
        
        return CGRect(x: cgX, y: cgY, width: viewRect.width, height: viewRect.height)
    }
    
    /// Returns the center of the selection in CG screen coordinates (for sending scroll events).
    public func selectionCenterInCGCoordinates() -> CGPoint {
        let cgRect = selectionInScreenCoordinates()
        return CGPoint(x: cgRect.midX, y: cgRect.midY)
    }
}
