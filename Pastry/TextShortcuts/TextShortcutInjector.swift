import Foundation
import CoreGraphics
import AppKit

/// Handles direct keyboard deletion and Unicode text injection into the active focused application.
/// 100% independent of NSPasteboard, clipboard history, or Cmd+V.
public class TextShortcutInjector {
    public static let shared = TextShortcutInjector()
    
    private let source = CGEventSource(stateID: .hidSystemState)
    
    private init() {}
    
    /// Deletes `charactersToDelete` characters by simulating backspace keys,
    /// then directly types the `replacement` string as Unicode characters.
    ///
    /// - Parameters:
    ///   - replacement: The exact text to inject (preserves newlines, case, and special characters).
    ///   - charactersToDelete: The length of the typed shortcut to erase before typing replacement.
    public func inject(replacement: String, charactersToDelete: Int) {
        guard !replacement.isEmpty || charactersToDelete > 0 else { return }
        
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            
            // 1. Send backspace events to delete the typed shortcut
            if charactersToDelete > 0 {
                self.sendBackspaces(count: charactersToDelete)
                // Small micro-delay to let target text field process backspaces
                Thread.sleep(forTimeInterval: 0.015)
            }
            
            // 2. Directly type replacement string via Unicode keyboard events
            if !replacement.isEmpty {
                self.sendUnicodeString(replacement)
            }
        }
    }
    
    // MARK: - Backspace Simulation
    
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
            
            // Micro pause between keystrokes for reliable consumption across fast editors
            Thread.sleep(forTimeInterval: 0.002)
        }
    }
    
    // MARK: - Direct Unicode Keystroke Typing
    
    private func sendUnicodeString(_ string: String) {
        let utf16 = Array(string.utf16)
        guard !utf16.isEmpty else { return }
        
        // Chunk long text into small blocks to guarantee reliable dispatch across all apps
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
}
