import Foundation
import AppKit
import ApplicationServices

public class PasteService {
    public static let shared = PasteService()
    
    private var previouslyActiveApp: NSRunningApplication?
    
    /// The text that was selected in the previous app when Pastry opened
    public private(set) var capturedSelectedText: String?
    
    private init() {}
    
    public func recordActiveApp() {
        if let app = NSWorkspace.shared.frontmostApplication,
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            previouslyActiveApp = app
        }
    }
    
    /// Captures the currently selected text from the frontmost application
    /// by simulating ⌘C, reading the clipboard, then restoring the original clipboard.
    /// Must be called BEFORE Pastry takes focus (i.e., before the panel is shown).
    public func captureSelectedText() {
        capturedSelectedText = nil
        
        guard isAccessibilityPermissionGranted() else { return }
        
        let pasteboard = NSPasteboard.general
        
        // 1. Save current clipboard state
        let savedChangeCount = pasteboard.changeCount
        let savedTypes = pasteboard.types ?? []
        var savedData: [(NSPasteboard.PasteboardType, Data)] = []
        for type in savedTypes {
            if let data = pasteboard.data(forType: type) {
                savedData.append((type, data))
            }
        }
        
        // 2. Simulate ⌘C to copy the current selection
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let cDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true) else { return }
        cDown.flags = .maskCommand
        guard let cUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false) else { return }
        cUp.flags = .maskCommand
        
        cDown.post(tap: .cghidEventTap)
        cUp.post(tap: .cghidEventTap)
        
        // 3. Wait briefly for the copy to take effect
        usleep(80_000) // 80ms
        
        // 4. Read the new clipboard content
        if pasteboard.changeCount != savedChangeCount {
            capturedSelectedText = pasteboard.string(forType: .string)
        }
        
        // 5. Restore the original clipboard contents
        ClipboardManager.shared.writeWithoutMonitoring {
            pasteboard.clearContents()
            for (type, data) in savedData {
                pasteboard.setData(data, forType: type)
            }
        }
    }
    
    // MARK: - Normal paste (Mode 1) — existing behavior, unchanged
    
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
        
        app.activate()
        
        // 3. Wait for focus transfer, then simulate Command+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.075) {
            let success = self.triggerSystemPaste()
            completion(success)
        }
    }
    
    // MARK: - Calculation insert (Mode 2) — insert result AFTER the selected text
    
    public func restoreActiveAppAndInsertAfterSelection(resultText: String, completion: @escaping (Bool) -> Void) {
        guard let app = previouslyActiveApp else {
            completion(false)
            return
        }
        
        app.activate()
        
        // Wait for focus transfer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.075) {
            guard self.isAccessibilityPermissionGranted() else {
                completion(false)
                return
            }
            
            let source = CGEventSource(stateID: .combinedSessionState)
            
            // Step 1: Press → (Right Arrow, keycode 124) to deselect and move cursor
            //         to the END of the current selection without deleting the selection
            guard let rightDown = CGEvent(keyboardEventSource: source, virtualKey: 124, keyDown: true) else {
                completion(false)
                return
            }
            guard let rightUp = CGEvent(keyboardEventSource: source, virtualKey: 124, keyDown: false) else {
                completion(false)
                return
            }
            rightDown.post(tap: .cghidEventTap)
            rightUp.post(tap: .cghidEventTap)
            
            // Step 2: Small delay, then put " <result>" on clipboard and paste
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                ClipboardManager.shared.writeWithoutMonitoring {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(" " + resultText, forType: .string)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                    let success = self.triggerSystemPaste()
                    completion(success)
                }
            }
        }
    }
    
    // MARK: - Accessibility
    
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
    
    // MARK: - Private helpers
    
    private func writeItemToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if let reps = item.representations, !reps.isEmpty {
            for (typeStr, data) in reps {
                pasteboard.setData(data, forType: NSPasteboard.PasteboardType(typeStr))
            }
            return
        }
        
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
        
        guard let vDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) else { return false }
        vDown.flags = .maskCommand
        
        guard let vUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { return false }
        vUp.flags = .maskCommand
        
        vDown.post(tap: .cghidEventTap)
        vUp.post(tap: .cghidEventTap)
        return true
    }
}

