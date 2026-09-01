import Foundation
import CoreGraphics
import AppKit

/// Handles shortcut expansion into the active focused application.
/// - Text shortcuts: 100% direct Unicode keyboard injection (zero clipboard / pasteboard usage).
/// - Image shortcuts: Temporary pasteboard snapshot → isolated paste → full clipboard restoration.
public class TextShortcutInjector {
    public static let shared = TextShortcutInjector()
    
    private let source = CGEventSource(stateID: .hidSystemState)
    
    /// Settlement delay (in seconds) allowing the target application to consume
    /// the temporary pasteboard image before restoring the user's original clipboard.
    public var imagePasteSettlementDelay: TimeInterval = 0.35
    
    private init() {}
    
    /// Expands the matched shortcut into the active focused application.
    public func inject(shortcut: TextShortcut, charactersToDelete: Int) {
        switch shortcut.type {
        case .text:
            guard let text = shortcut.textContent, !text.isEmpty || charactersToDelete > 0 else { return }
            injectText(replacement: text, charactersToDelete: charactersToDelete)
            
        case .image:
            guard let assetFilename = shortcut.imageAsset,
                  let imageData = ShortcutAssetStorage.shared.loadImageData(assetFilename: assetFilename) else {
                return
            }
            injectImage(imageData: imageData, charactersToDelete: charactersToDelete)
        }
    }
    
    // MARK: - Direct Text Injection (Zero Clipboard Interaction)
    
    /// Directly deletes typed characters via backspaces and types the replacement text as Unicode characters.
    /// Never touches NSPasteboard or simulates Cmd+V.
    public func injectText(replacement: String, charactersToDelete: Int) {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            
            // 1. Send backspaces to delete typed shortcut
            if charactersToDelete > 0 {
                self.sendBackspaces(count: charactersToDelete)
                Thread.sleep(forTimeInterval: 0.015)
            }
            
            // 2. Directly type replacement string via Unicode keyboard events
            if !replacement.isEmpty {
                self.sendUnicodeString(replacement)
            }
        }
    }
    
    // MARK: - Image Injection (Isolated Pasteboard with Full Restoration)
    
    /// Expands an image shortcut by snapshotting current pasteboard, temporarily pasting the image,
    /// and restoring the user's exact prior clipboard state after the target app has consumed the paste.
    public func injectImage(imageData: Data, charactersToDelete: Int) {
        guard let image = NSImage(data: imageData) else { return }
        
        DispatchQueue.main.async {
            // 1. Capture user's complete existing pasteboard snapshot
            let snapshot = PasteboardSnapshot.captureCurrent()
            
            // 2. Send backspaces to delete the typed shortcut
            if charactersToDelete > 0 {
                self.sendBackspaces(count: charactersToDelete)
                Thread.sleep(forTimeInterval: 0.02)
            }
            
            // 3. Temporarily write image to pasteboard with ClipboardManager monitoring suppressed
            ClipboardManager.shared.writeWithoutMonitoring {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                
                let item = NSPasteboardItem()
                item.setData(imageData, forType: .png)
                if let tiffData = image.tiffRepresentation {
                    item.setData(tiffData, forType: .tiff)
                }
                pasteboard.writeObjects([item, image])
            }
            
            // 4. Simulate Command+V paste
            self.triggerSystemPaste()
            
            // 5. Restore user's original pasteboard state after target app has consumed the image
            let delay = self.imagePasteSettlementDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                ClipboardManager.shared.writeWithoutMonitoring {
                    snapshot.restore()
                }
            }
        }
    }
    
    // MARK: - Keyboard Simulation Helpers
    
    private func sendBackspaces(count: Int) {
        let backspaceKeyCode: CGKeyCode = 51 // Backspace / Delete keycode on macOS
        
        for _ in 0..<count {
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: backspaceKeyCode, keyDown: true) {
                keyDown.flags = []
                keyDown.post(tap: .cghidEventTap)
            }
            
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: backspaceKeyCode, keyDown: false) {
                keyUp.flags = []
                keyUp.post(tap: .cghidEventTap)
            }
            
            Thread.sleep(forTimeInterval: 0.002)
        }
    }
    
    private func sendUnicodeString(_ string: String) {
        let utf16 = Array(string.utf16)
        guard !utf16.isEmpty else { return }
        
        let chunkSize = 20
        var index = 0
        
        while index < utf16.count {
            let endIndex = min(index + chunkSize, utf16.count)
            let chunk = Array(utf16[index..<endIndex])
            
            if let eventDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                eventDown.flags = []
                eventDown.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                eventDown.post(tap: .cghidEventTap)
            }
            
            if let eventUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                eventUp.flags = []
                eventUp.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                eventUp.post(tap: .cghidEventTap)
            }
            
            index += chunkSize
            Thread.sleep(forTimeInterval: 0.003)
        }
    }
    
    private func triggerSystemPaste() {
        let vKeyCode: CGKeyCode = 9 // V key on macOS
        
        if let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) {
            vDown.flags = .maskCommand
            vDown.post(tap: .cghidEventTap)
        }
        
        if let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) {
            vUp.flags = .maskCommand
            vUp.post(tap: .cghidEventTap)
        }
    }
}

// MARK: - Pasteboard Snapshot Helper

/// Full multi-item snapshot of NSPasteboard.general for exact restoration.
private struct PasteboardSnapshot {
    struct ItemRepresentation {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }
    
    let items: [[ItemRepresentation]]
    let stringFallback: String?
    
    static func captureCurrent() -> PasteboardSnapshot {
        let pb = NSPasteboard.general
        var capturedItems: [[ItemRepresentation]] = []
        
        if let pasteboardItems = pb.pasteboardItems {
            for pbItem in pasteboardItems {
                var reps: [ItemRepresentation] = []
                for type in pbItem.types {
                    if let data = pbItem.data(forType: type) {
                        reps.append(ItemRepresentation(type: type, data: data))
                    }
                }
                if !reps.isEmpty {
                    capturedItems.append(reps)
                }
            }
        }
        
        return PasteboardSnapshot(
            items: capturedItems,
            stringFallback: pb.string(forType: .string)
        )
    }
    
    func restore() {
        let pb = NSPasteboard.general
        pb.clearContents()
        
        guard !items.isEmpty else {
            if let str = stringFallback {
                pb.setString(str, forType: .string)
            }
            return
        }
        
        for itemReps in items {
            let newItem = NSPasteboardItem()
            for rep in itemReps {
                newItem.setData(rep.data, forType: rep.type)
            }
            pb.writeObjects([newItem])
        }
    }
}
