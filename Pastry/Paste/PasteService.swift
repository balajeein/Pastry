import Foundation
import AppKit
import ApplicationServices

public class PasteService {
    public static let shared = PasteService()
    
    private var previouslyActiveApp: NSRunningApplication?
    
    private init() {}
    
    public func recordActiveApp() {
        if let app = NSWorkspace.shared.frontmostApplication,
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            previouslyActiveApp = app
        }
    }
    
    public func restoreActiveAppAndPaste(item: ClipboardItem, completion: @escaping (Bool) -> Void) {
        // 1. Write the selected item to the pasteboard
        ClipboardManager.shared.writeWithoutMonitoring {
            self.writeItemToPasteboard(item)
        }
        
        // 2. Restore focus to the previous application
        guard let app = previouslyActiveApp else {
            completion(false)
            return
        }
        
        // Activate target application ignoring other apps
        app.activate()
        
        // 3. Wait for focus transfer, then simulate Command+V
        // 75ms is the optimal delay (minimizes visible lag while ensuring focus has shifted)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.075) {
            let success = self.triggerSystemPaste()
            completion(success)
        }
    }
    
    public func isAccessibilityPermissionGranted() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    public func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func writeItemToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // Try restoring using saved raw representations first (great for preserving complex formats)
        if let reps = item.representations, !reps.isEmpty {
            for (typeStr, data) in reps {
                pasteboard.setData(data, forType: NSPasteboard.PasteboardType(typeStr))
            }
            return
        }
        
        // Fallback reconstruction if representations are missing or if it is a disk-stored image
        switch item.type {
        case .text:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        case .url:
            if let text = item.textContent, let url = URL(string: text) {
                pasteboard.writeObjects([url as NSPasteboardWriting])
            }
        case .file:
            if let text = item.textContent {
                let fileURLs = text.components(separatedBy: "\n").compactMap { URL(string: $0) }
                if !fileURLs.isEmpty {
                    pasteboard.writeObjects(fileURLs as [NSPasteboardWriting])
                }
            }
        case .image:
            if let path = item.storagePath, let data = ImageStorage.shared.loadImage(path: path) {
                pasteboard.setData(data, forType: .png)
            }
        case .other:
            break
        }
    }
    
    private func triggerSystemPaste() -> Bool {
        guard isAccessibilityPermissionGranted() else {
            return false
        }
        
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // V key is keycode 9
        guard let vDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) else { return false }
        vDown.flags = .maskCommand
        
        guard let vUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { return false }
        vUp.flags = .maskCommand
        
        vDown.post(tap: .cghidEventTap)
        vUp.post(tap: .cghidEventTap)
        return true
    }
}
