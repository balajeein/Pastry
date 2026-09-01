import Foundation
import AppKit
import CoreGraphics
import CryptoKit

/// Orchestrates the full Scroll Screenshot workflow:
/// overlay → selection → target app activation → capture loop → stitch → save → add to history.
public class ScrollScreenshotController {
    public static let shared = ScrollScreenshotController()
    
    private var overlayWindow: ScrollScreenshotOverlayWindow?
    private var capturedFrames: [CGImage] = []
    private var isCapturing = false
    private var shouldStop = false
    private var isCursorPushed = false
    
    // Incremental stitching state (used during capture loop)
    private var stitchedImage: CGImage?
    private var previousFrame: CGImage?
    private var stitchedFrameCount: Int = 0
    
    /// Scroll capture direction (defaults to vertical, can be set to horizontal via Options)
    public var scrollDirection: ImageStitcher.StitchDirection = .vertical
    
    private var stopGlobalMonitor: Any?
    private var stopLocalMonitor: Any?
    
    /// The number of consecutive identical frames before auto-stopping.
    private let maxIdenticalFrames = 3
    
    /// Delay after each scroll event to let content settle (in seconds).
    private let settleDelay: TimeInterval = 0.40
    
    /// Delay between capture and next scroll.
    private let captureDelay: TimeInterval = 0.10
    
    private init() {}
    
    // MARK: - Public API
    
    /// Starts the scroll screenshot workflow. Call after dismissing the Pastry panel.
    public func startCapture(on screen: NSScreen? = nil) {
        // Check permissions first
        if !PasteService.shared.isAccessibilityPermissionGranted() {
            showPermissionAlert(
                title: "Accessibility Permission Required",
                message: "Pastry needs Accessibility permission to send scroll events to other applications.\n\nPlease grant Accessibility access in System Preferences → Security & Privacy → Privacy → Accessibility.",
                settingsAction: { PasteService.shared.openAccessibilitySettings() }
            )
            return
        }
        
        if !ScrollScreenshotController.isScreenRecordingGranted() {
            showPermissionAlert(
                title: "Screen Recording Permission Required",
                message: "Pastry needs Screen Recording permission to capture screen regions.\n\nPlease grant Screen Recording access in System Preferences → Security & Privacy → Privacy → Screen Recording.",
                settingsAction: { ScrollScreenshotController.openScreenRecordingSettings() }
            )
            return
        }
        
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first!
        
        // Clean up any existing overlay
        cleanup()
        
        // Pause screenshot tracking baseline to avoid picking up intermediate files
        ScreenshotMonitor.shared.updateBaselineToNow()
        
        // Create overlay after a brief delay to let the Pastry panel fully close
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.showOverlay(on: targetScreen)
        }
    }
    
    // MARK: - Screen Recording Permission
    
    /// Checks if Screen Recording permission is granted by attempting a small capture.
    public static func isScreenRecordingGranted() -> Bool {
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        guard let image = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) else {
            return false
        }
        return image.width > 0 && image.height > 0
    }
    
    /// Opens the Screen Recording section of System Preferences.
    public static func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Overlay Management
    
    private func showOverlay(on screen: NSScreen) {
        let overlay = ScrollScreenshotOverlayWindow(screen: screen)
        overlay.overlayView.scrollDirection = self.scrollDirection
        
        overlay.overlayView.onCapture = { [weak self] in
            self?.beginCaptureLoop()
        }
        
        overlay.overlayView.onCancel = { [weak self] in
            self?.cancelCapture()
        }
        
        self.overlayWindow = overlay
        
        overlay.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - Target Application Identification
    
    /// Identifies the application and PID underneath the given point on screen.
    private func identifyTargetApplication(at point: CGPoint) -> (pid: pid_t, app: NSRunningApplication?)? {
        let myPID = ProcessInfo.processInfo.processIdentifier
        
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            if let frontApp = NSWorkspace.shared.frontmostApplication, frontApp.processIdentifier != myPID {
                return (frontApp.processIdentifier, frontApp)
            }
            return nil
        }
        
        for window in windowList {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t, pid != myPID else {
                continue
            }
            
            // Skip System UI and Pastry
            if let ownerName = window[kCGWindowOwnerName as String] as? String {
                let lower = ownerName.lowercased()
                if lower == "dock" || lower == "window server" || lower == "control center" || lower == "systemuiserver" || lower == "pastry" {
                    continue
                }
            }
            
            // Check if point falls within window bounds
            if let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
               let windowRect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                if windowRect.contains(point) {
                    let app = NSRunningApplication(processIdentifier: pid)
                    return (pid, app)
                }
            }
        }
        
        // Fallback: frontmost active app that is not Pastry
        if let frontApp = NSWorkspace.shared.frontmostApplication, frontApp.processIdentifier != myPID {
            return (frontApp.processIdentifier, frontApp)
        }
        
        return nil
    }
    
    // MARK: - Capture Loop
    
    private func beginCaptureLoop() {
        guard let overlay = overlayWindow else { return }
        
        // 1. Lock selection and configure overlay for live capture
        overlay.overlayView.isLocked = true
        overlay.overlayView.isCapturing = true
        overlay.overlayView.frameCount = 0
        
        // Make overlay click-through so target app receives events directly
        overlay.ignoresMouseEvents = true
        
        // Change mouse cursor to camera icon
        DispatchQueue.main.async { [weak self] in
            if self?.isCursorPushed == false {
                NSCursor.cameraCursor.push()
                self?.isCursorPushed = true
            }
        }
        
        capturedFrames = []
        isCapturing = true
        shouldStop = false
        
        // 2. Compute exact capture region and scroll target
        let captureRect = overlay.selectionInScreenCoordinates()
        let scrollCenter = overlay.selectionCenterInCGCoordinates()
        let overlayWindowNumber = overlay.windowNumber
        let direction = self.scrollDirection
        
        // Calculate proportional scroll step (approx 45% of dimension)
        let rawDelta: Int32
        switch direction {
        case .vertical:
            rawDelta = Int32(max(80, min(260, captureRect.height * 0.45)))
        case .horizontal:
            rawDelta = Int32(max(80, min(260, captureRect.width * 0.45)))
        }
        let scrollDelta: Int32 = -rawDelta // Negative for scrolling down/right
        
        // 3. Identify and activate the target application
        let targetInfo = identifyTargetApplication(at: scrollCenter)
        let targetPID = targetInfo?.pid
        let targetApp = targetInfo?.app
        
        print("[ScrollScreenshot] Direction: \(direction.rawValue)")
        print("[ScrollScreenshot] Target PID: \(targetPID ?? 0) (\(targetApp?.localizedName ?? "Unknown"))")
        print("[ScrollScreenshot] Capture region: \(captureRect)")
        
        // Focus the target application so it responds immediately to wheel events
        if let targetApp = targetApp {
            if #available(macOS 14.0, *) {
                targetApp.activate()
            } else {
                targetApp.activate(options: .activateIgnoringOtherApps)
            }
        }
        
        // 4. Install Stop monitor with a 0.25s debounce to ignore the initial Capture click
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self, self.isCapturing else { return }
            self.installStopMonitors()
        }
        
        // 5. Start background capture loop
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            Thread.sleep(forTimeInterval: 0.15)
            
            self?.runCaptureLoop(
                captureRect: captureRect,
                scrollCenter: scrollCenter,
                scrollDelta: scrollDelta,
                direction: direction,
                targetPID: targetPID,
                overlayWindowNumber: overlayWindowNumber
            )
        }
    }
    
    private func installStopMonitors() {
        stopGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            if event.type == .keyDown && event.keyCode == 53 { // Escape
                print("[ScrollScreenshot] Escape pressed via global monitor")
                self?.cancelCapture()
            } else {
                print("[ScrollScreenshot] User clicked on screen with camera cursor — stopping capture")
                self?.stopCapture()
            }
        }
        
        stopLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            if event.type == .keyDown && event.keyCode == 53 { // Escape
                print("[ScrollScreenshot] Escape pressed via local monitor")
                self?.cancelCapture()
            } else {
                print("[ScrollScreenshot] User clicked locally with camera cursor — stopping capture")
                self?.stopCapture()
            }
            return nil
        }
    }
    
    private func removeStopMonitors() {
        if let m = stopGlobalMonitor {
            NSEvent.removeMonitor(m)
            stopGlobalMonitor = nil
        }
        if let m = stopLocalMonitor {
            NSEvent.removeMonitor(m)
            stopLocalMonitor = nil
        }
    }
    
    private func runCaptureLoop(
        captureRect: CGRect,
        scrollCenter: CGPoint,
        scrollDelta: Int32,
        direction: ImageStitcher.StitchDirection,
        targetPID: pid_t?,
        overlayWindowNumber: Int
    ) {
        var consecutiveIdenticalCount = 0
        var consecutiveFailureCount = 0
        var lastFrameHash: String? = nil
        var frameIndex = 0
        
        // Reset incremental stitching state
        stitchedImage = nil
        previousFrame = nil
        stitchedFrameCount = 0
        
        while !shouldStop {
            // 1. Capture the region
            guard let frame = captureRegion(rect: captureRect, excludingWindow: overlayWindowNumber) else {
                print("[ScrollScreenshot] Screen capture failed")
                DispatchQueue.main.async { [weak self] in
                    self?.handleCaptureError(message: "Screen capture failed. Please verify Screen Recording permissions.")
                }
                return
            }
            
            frameIndex += 1
            print("[ScrollScreenshot] Captured frame: \(frameIndex)")
            
            // 2. Check for duplicate/unchanged frame via hash
            let frameHash = hashFrame(frame)
            let isFirst = (previousFrame == nil)
            let frameChanged = !isFirst && (frameHash != lastFrameHash)
            
            if !isFirst {
                print("[ScrollScreenshot] Frame changed: \(frameChanged)")
                if !frameChanged {
                    consecutiveIdenticalCount += 1
                    if consecutiveIdenticalCount >= maxIdenticalFrames {
                        print("[ScrollScreenshot] Reached end of scrollable content (identical frames: \(consecutiveIdenticalCount))")
                        break
                    }
                    // Skip this identical frame — scroll and try again
                } else {
                    consecutiveIdenticalCount = 0
                }
            }
            lastFrameHash = frameHash
            
            // 3. Process the frame
            if isFirst {
                // First frame: initialize the stitched image
                stitchedImage = frame
                previousFrame = frame
                stitchedFrameCount = 1
                capturedFrames.append(frame)
                
                DispatchQueue.main.async { [weak self] in
                    self?.overlayWindow?.overlayView.frameCount = self?.stitchedFrameCount ?? 0
                    self?.overlayWindow?.overlayView.needsDisplay = true
                }
            } else if frameChanged {
                // Use Vision to measure actual displacement
                if let prevFrame = previousFrame,
                   let translation = ImageStitcher.detectTranslation(from: prevFrame, to: frame) {
                    
                    if translation.isValid {
                        let displacement = Int(translation.dy.rounded())
                        print("[ScrollScreenshot] Vision displacement: \(displacement) px (confidence: \(translation.confidence))")
                        
                        if let base = stitchedImage,
                           let newStitched = ImageStitcher.appendFrame(baseImage: base, newFrame: frame,
                                                                       displacementPixels: displacement) {
                            stitchedImage = newStitched
                            previousFrame = frame
                            stitchedFrameCount += 1
                            consecutiveFailureCount = 0
                            capturedFrames.append(frame)
                            
                            DispatchQueue.main.async { [weak self] in
                                self?.overlayWindow?.overlayView.frameCount = self?.stitchedFrameCount ?? 0
                                self?.overlayWindow?.overlayView.needsDisplay = true
                            }
                        } else {
                            print("[ScrollScreenshot] Failed to append frame \(frameIndex)")
                            consecutiveFailureCount += 1
                        }
                    } else {
                        print("[ScrollScreenshot] Vision translation invalid (dy=\(translation.dy), confidence=\(translation.confidence))")
                        // Frame content changed but alignment failed — store as previousFrame
                        // so next comparison has a better reference
                        previousFrame = frame
                        consecutiveFailureCount += 1
                    }
                } else {
                    print("[ScrollScreenshot] Vision detection returned nil for frame \(frameIndex)")
                    previousFrame = frame
                    consecutiveFailureCount += 1
                }
                
                // Safety: stop after too many consecutive failures
                if consecutiveFailureCount >= 5 {
                    print("[ScrollScreenshot] Too many consecutive alignment failures, stopping")
                    break
                }
            }
            
            // Brief pause before scrolling
            Thread.sleep(forTimeInterval: captureDelay)
            
            if shouldStop {
                print("[ScrollScreenshot] Stop requested before next scroll")
                break
            }
            
            // 4. Scroll in the requested direction
            print("[ScrollScreenshot] Sending \(direction.rawValue) scroll: delta=\(scrollDelta) at \(scrollCenter)")
            sendScrollEvent(at: scrollCenter, targetPID: targetPID, delta: scrollDelta, direction: direction)
            
            // 5. Wait for content to settle
            print("[ScrollScreenshot] Waiting for content...")
            Thread.sleep(forTimeInterval: settleDelay)
        }
        
        print("[ScrollScreenshot] Capture loop finished. Total frames stitched: \(stitchedFrameCount)")
        DispatchQueue.main.async { [weak self] in
            self?.finishCapture(direction: direction)
        }
    }
    
    // MARK: - Screen Capture
    
    /// Captures a screen region, excluding the overlay window.
    /// Uses `.bestResolution` only to get native Retina resolution.
    private func captureRegion(rect: CGRect, excludingWindow: Int) -> CGImage? {
        let windowID = CGWindowID(excludingWindow)
        return CGWindowListCreateImage(
            rect,
            .optionOnScreenBelowWindow,
            windowID,
            .bestResolution
        )
    }
    
    // MARK: - Scroll Events
    
    /// Sends a SINGLE pixel-based scroll event in the specified direction.
    /// Only one event is posted to one destination to ensure predictable displacement.
    private func sendScrollEvent(at point: CGPoint, targetPID: pid_t?, delta: Int32, direction: ImageStitcher.StitchDirection) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Move mouse cursor to the scroll center location
        if let moveEvent = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                                    mouseCursorPosition: point, mouseButton: .left) {
            moveEvent.post(tap: .cghidEventTap)
        }
        
        // Small delay to let cursor position settle before scroll
        Thread.sleep(forTimeInterval: 0.02)
        
        switch direction {
        case .vertical:
            // Single pixel-based vertical scroll event
            if let scrollEvent = CGEvent(
                scrollWheelEvent2Source: source,
                units: .pixel,
                wheelCount: 1,
                wheel1: delta,
                wheel2: 0,
                wheel3: 0
            ) {
                scrollEvent.location = point
                // Post only once — prefer HID tap for broadest app compatibility
                scrollEvent.post(tap: .cghidEventTap)
            }
            
        case .horizontal:
            // Single pixel-based horizontal scroll event
            if let scrollEvent = CGEvent(
                scrollWheelEvent2Source: source,
                units: .pixel,
                wheelCount: 2,
                wheel1: 0,
                wheel2: delta,
                wheel3: 0
            ) {
                scrollEvent.location = point
                scrollEvent.post(tap: .cghidEventTap)
            }
        }
    }
    
    // MARK: - Frame Hashing
    
    private func hashFrame(_ frame: CGImage) -> String {
        guard let data = ImageStitcher.pngData(from: frame) else { return UUID().uuidString }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Stop / Cancel
    
    public func stopCapture() {
        shouldStop = true
    }
    
    public func cancelCapture() {
        shouldStop = true
        capturedFrames = []
        cleanup()
    }
    
    // MARK: - Finish & Stitch
    
    private func finishCapture(direction: ImageStitcher.StitchDirection) {
        removeStopMonitors()
        
        // For vertical direction with incremental stitching, use the already-built image
        if direction == .vertical, let finalImage = stitchedImage, stitchedFrameCount > 0 {
            let image = finalImage
            let frameCount = stitchedFrameCount
            cleanup()
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let data = ImageStitcher.pngData(from: image) else {
                    DispatchQueue.main.async {
                        self?.showErrorAlert(message: "Failed to encode the stitched screenshot.")
                    }
                    return
                }
                
                let result = ImageStitcher.StitchResult(
                    image: image,
                    pngData: data,
                    frameCount: frameCount,
                    totalWidth: image.width,
                    totalHeight: image.height
                )
                
                DispatchQueue.main.async {
                    self?.saveResult(result)
                }
            }
            return
        }
        
        // Fallback: batch stitch (horizontal direction or if incremental wasn't used)
        guard !capturedFrames.isEmpty else {
            cleanup()
            return
        }
        
        let frames = capturedFrames
        cleanup()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let result = ImageStitcher.stitch(frames: frames, direction: direction) else {
                DispatchQueue.main.async {
                    self?.showErrorAlert(message: "Failed to stitch captured frames together.")
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.saveResult(result)
            }
        }
    }
    
    // MARK: - Save Result
    
    private func saveResult(_ result: ImageStitcher.StitchResult) {
        let pngData = result.pngData
        
        // 1. Save to Desktop
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let timestamp = formatter.string(from: Date())
        let filename = "Pastry-ScrollCapture-\(timestamp).png"
        let fileURL = desktopURL.appendingPathComponent(filename)
        
        do {
            try pngData.write(to: fileURL)
            print("[ScrollScreenshot] Saved stitched screenshot to: \(fileURL.path)")
        } catch {
            showErrorAlert(message: "Failed to save scroll screenshot to Desktop: \(error.localizedDescription)")
            return
        }
        
        // 2. Add to Pastry clipboard history
        let id = UUID()
        guard let paths = ImageStorage.shared.saveImage(data: pngData, id: id) else {
            showErrorAlert(message: "Failed to save scroll screenshot to Pastry storage.")
            return
        }
        
        let digest = SHA256.hash(data: pngData)
        let hashString = digest.map { String(format: "%02x", $0) }.joined()
        
        let sizeDesc = ImageStorage.shared.getImageSizeDescription(path: paths.imagePath) ?? "Scroll Screenshot"
        let item = ClipboardItem(
            id: id,
            type: .image,
            timestamp: Date(),
            storagePath: paths.imagePath,
            displayTitle: "Scroll Screenshot",
            subtitle: "\(result.frameCount) frames stitched · \(sizeDesc)",
            contentHash: hashString
        )
        
        ClipboardStore.shared.add(item: item)
        print("[ScrollScreenshot] Added stitched screenshot to Pastry clipboard history")
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        isCapturing = false
        shouldStop = true
        removeStopMonitors()
        
        DispatchQueue.main.async { [weak self] in
            if self?.isCursorPushed == true {
                NSCursor.pop()
                self?.isCursorPushed = false
            }
        }
        
        overlayWindow?.close()
        overlayWindow = nil
        capturedFrames = []
        stitchedImage = nil
        previousFrame = nil
        stitchedFrameCount = 0
    }
    
    // MARK: - Error Handling
    
    private func handleCaptureError(message: String) {
        cleanup()
        showErrorAlert(message: message)
    }
    
    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Scroll Screenshot"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showPermissionAlert(title: String, message: String, settingsAction: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            settingsAction()
        }
    }
}
