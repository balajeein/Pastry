import Foundation
import AppKit
import CoreGraphics

// MARK: - Custom Camera Cursor

extension NSCursor {
    /// Custom crosshair cursor with a camera icon badge for the scroll screenshot tool.
    static let cameraCursor: NSCursor = {
        let size = NSSize(width: 32, height: 32)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Draw crisp dark crosshair
        NSColor.white.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 2.5
        path.move(to: NSPoint(x: 16, y: 4))
        path.line(to: NSPoint(x: 16, y: 28))
        path.move(to: NSPoint(x: 4, y: 16))
        path.line(to: NSPoint(x: 28, y: 16))
        path.stroke()
        
        NSColor.black.setStroke()
        let innerPath = NSBezierPath()
        innerPath.lineWidth = 1.0
        innerPath.move(to: NSPoint(x: 16, y: 5))
        innerPath.line(to: NSPoint(x: 16, y: 27))
        innerPath.move(to: NSPoint(x: 5, y: 16))
        innerPath.line(to: NSPoint(x: 27, y: 16))
        innerPath.stroke()
        
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
        
        // Draw selection border: white dash-dotted line with black stroke backing for maximum contrast
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(2.0)
        context.setLineDash(phase: 0, lengths: [])
        context.stroke(selectionRect)
        
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.5)
        // Dash-dot pattern: dash(6), gap(3), dot(2), gap(3)
        context.setLineDash(phase: 0, lengths: [6, 3, 2, 3])
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
    
    // MARK: - Native macOS HUD Control Bar (Simple Clean Bar with One Capture Button)
    
    private func drawHUDControlBar(context: CGContext) {
        let barWidth: CGFloat = 142
        let barHeight: CGFloat = 44
        let cornerRadius: CGFloat = 14
        
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
        context.setFillColor(NSColor(calibratedWhite: 0.14, alpha: 0.94).cgColor)
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
        let closeBtnX = barX + 12
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
        let sepX = closeButtonRect.maxX + 10
        let sepY = barY + 12
        let sepHeight: CGFloat = barHeight - 24
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.16).cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: sepX, y: sepY))
        context.addLine(to: CGPoint(x: sepX, y: sepY + sepHeight))
        context.strokePath()
        
        // 4. Button 2: Capture vibrant blue pill button on the right
        let capWidth: CGFloat = 78
        let capHeight: CGFloat = 30
        let capX = sepX + 10
        let capY = barY + (barHeight - capHeight) / 2
        captureButtonRect = NSRect(x: capX, y: capY, width: capWidth, height: capHeight)
        
        let capPath = CGPath(roundedRect: captureButtonRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
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
    
    // MARK: - Mouse Handling
    
    override func mouseDown(with event: NSEvent) {
        guard !isLocked && !isCapturing else { return }
        
        let point = convert(event.locationInWindow, from: nil)
        
        // 1. Close (X) button
        if closeButtonRect.contains(point) {
            onCancel?()
            return
        }
        
        // 2. Capture button
        if captureButtonRect.contains(point) {
            onCapture?()
            return
        }
        
        // If clicking anywhere inside HUD bar background, don't drag selection
        if hudBarRect.contains(point) {
            return
        }
        
        // 3. Resize handles
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
        
        // 4. Move selection
        if selectionRect.contains(point) {
            dragMode = .move
            dragStartPoint = point
            dragStartRect = selectionRect
            return
        }
        
        // 5. Start a new selection if clicked outside
        dragMode = .resizeBottomRight
        dragStartPoint = point
        selectionRect = NSRect(x: point.x, y: point.y, width: 0, height: 0)
        dragStartRect = selectionRect
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard !isLocked && !isCapturing else { return }
        guard dragMode != .none else { return }
        
        let point = convert(event.locationInWindow, from: nil)
        let deltaX = point.x - dragStartPoint.x
        let deltaY = point.y - dragStartPoint.y
        
        var newRect = dragStartRect
        
        switch dragMode {
        case .none:
            break
            
        case .move:
            newRect.origin.x += deltaX
            newRect.origin.y += deltaY
            // Clamp to window bounds
            newRect.origin.x = max(0, min(newRect.origin.x, bounds.width - newRect.width))
            newRect.origin.y = max(0, min(newRect.origin.y, bounds.height - newRect.height))
            
        case .resizeTopLeft:
            newRect.origin.x += deltaX
            newRect.size.width -= deltaX
            newRect.size.height += deltaY
            
        case .resizeTop:
            newRect.size.height += deltaY
            
        case .resizeTopRight:
            newRect.size.width += deltaX
            newRect.size.height += deltaY
            
        case .resizeLeft:
            newRect.origin.x += deltaX
            newRect.size.width -= deltaX
            
        case .resizeRight:
            newRect.size.width += deltaX
            
        case .resizeBottomLeft:
            newRect.origin.x += deltaX
            newRect.size.width -= deltaX
            newRect.origin.y += deltaY
            newRect.size.height -= deltaY
            
        case .resizeBottom:
            newRect.origin.y += deltaY
            newRect.size.height -= deltaY
            
        case .resizeBottomRight:
            newRect.size.width += deltaX
            newRect.origin.y += deltaY
            newRect.size.height -= deltaY
        }
        
        // Normalize rect (handle negative width/height)
        var normalized = newRect
        if normalized.size.width < 0 {
            normalized.origin.x += normalized.size.width
            normalized.size.width = abs(normalized.size.width)
        }
        if normalized.size.height < 0 {
            normalized.origin.y += normalized.size.height
            normalized.size.height = abs(normalized.size.height)
        }
        
        // Enforce minimum size
        if normalized.size.width >= minSelectionSize && normalized.size.height >= minSelectionSize {
            selectionRect = normalized
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        dragMode = .none
        window?.invalidateCursorRects(for: self)
    }
    
    override func resetCursorRects() {
        super.resetCursorRects()
        
        guard !isLocked && !isCapturing else { return }
        
        // Move cursor for inside selection
        addCursorRect(selectionRect, cursor: .openHand)
        
        // Resize cursors for handles
        let handles = getHandleRects()
        if handles.count >= 8 {
            addCursorRect(handles[0], cursor: .crosshair) // TL
            addCursorRect(handles[1], cursor: .resizeUpDown) // T
            addCursorRect(handles[2], cursor: .crosshair) // TR
            addCursorRect(handles[3], cursor: .resizeLeftRight) // L
            addCursorRect(handles[4], cursor: .resizeLeftRight) // R
            addCursorRect(handles[5], cursor: .crosshair) // BL
            addCursorRect(handles[6], cursor: .resizeUpDown) // B
            addCursorRect(handles[7], cursor: .crosshair) // BR
        }
        
        // Pointing hand for buttons in HUD bar
        addCursorRect(closeButtonRect, cursor: .pointingHand)
        addCursorRect(captureButtonRect, cursor: .pointingHand)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel?()
            return
        }
        if event.keyCode == 36 { // Return / Enter
            onCapture?()
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Overlay Window Controller

/// Full-screen transparent overlay window that displays the selection UI.
public class ScrollScreenshotOverlayWindow: NSWindow {
    
    let overlayView: ScrollScreenshotOverlayView
    
    public init(screen: NSScreen) {
        let frame = screen.frame
        self.overlayView = ScrollScreenshotOverlayView(frame: NSRect(origin: .zero, size: frame.size))
        
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.contentView = overlayView
        self.isReleasedWhenClosed = false
        
        // Position selection rectangle in the center of the screen initially
        let defaultWidth: CGFloat = 600
        let defaultHeight: CGFloat = 450
        let defaultX = (frame.width - defaultWidth) / 2
        let defaultY = (frame.height - defaultHeight) / 2
        overlayView.selectionRect = NSRect(x: defaultX, y: defaultY, width: defaultWidth, height: defaultHeight)
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
