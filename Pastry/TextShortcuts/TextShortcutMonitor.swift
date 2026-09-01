import Foundation
import CoreGraphics
import AppKit

/// Monitors keystrokes globally to track the word immediately before the cursor,
/// and detects `Option + Space` (⌥ + Space) to trigger direct text expansion.
public class TextShortcutMonitor {
    public static let shared = TextShortcutMonitor()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var typedBuffer: String = ""
    private let queue = DispatchQueue(label: "com.balajee.Pastry.TextShortcutMonitor", qos: .userInteractive)
    
    /// Maximum character buffer to track before cursor
    private let maxBufferLength = 60
    
    private init() {}
    
    // MARK: - Monitoring Lifecycle
    
    public func startMonitoring() {
        guard eventTap == nil else { return }
        
        // Event mask for KeyDown and LeftMouseDown (to reset buffer on click)
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.leftMouseDown.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<TextShortcutMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(type: type, event: event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            print("[TextShortcutMonitor] Failed to create CGEventTap — Accessibility permission required")
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[TextShortcutMonitor] Started monitoring for ⌥ + Space text shortcuts")
    }
    
    public func stopMonitoring() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
                self.runLoopSource = nil
            }
            self.eventTap = nil
        }
        typedBuffer = ""
    }
    
    // MARK: - Event Handling
    
    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Automatically re-enable tap if disabled by system timeout
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        
        // Reset buffer on mouse click (cursor moved)
        if type == .leftMouseDown {
            typedBuffer = ""
            return Unmanaged.passUnretained(event)
        }
        
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }
        
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        // Check for ⌥ + Space (Option + Space, keyCode 49)
        let isOptionPressed = flags.contains(.maskAlternate)
        let isCommandPressed = flags.contains(.maskCommand)
        let isControlPressed = flags.contains(.maskControl)
        
        if keyCode == 49 && isOptionPressed && !isCommandPressed && !isControlPressed {
            // If Pastry itself is active and has a key window, don't expand shortcuts in Pastry UI
            if let frontApp = NSWorkspace.shared.frontmostApplication,
               frontApp.bundleIdentifier == Bundle.main.bundleIdentifier {
                return Unmanaged.passUnretained(event)
            }
            
            // Extract the word immediately before the cursor
            if let match = resolveShortcutBeforeCursor() {
                // Suppress Option+Space and trigger direct injection
                let tokenLength = match.token.count
                typedBuffer = ""
                
                TextShortcutInjector.shared.inject(
                    shortcut: match.shortcut,
                    charactersToDelete: tokenLength
                )
                return nil // Suppress raw event
            }
            
            // No matching shortcut found: pass Option+Space through untouched
            return Unmanaged.passUnretained(event)
        }
        
        // Update in-memory typing buffer for subsequent lookups
        updateTypingBuffer(keyCode: keyCode, event: event, flags: flags)
        
        return Unmanaged.passUnretained(event)
    }
    
    // MARK: - Buffer & Token Resolution
    
    private func updateTypingBuffer(keyCode: Int64, event: CGEvent, flags: CGEventFlags) {
        // Reset buffer on navigation / action keys
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            typedBuffer = ""
            return
        }
        
        switch keyCode {
        case 51: // Backspace
            if !typedBuffer.isEmpty {
                typedBuffer.removeLast()
            }
        case 36, 48, 53, 123, 124, 125, 126: // Return, Tab, Escape, Arrow keys
            typedBuffer = ""
        default:
            // Extract typed unicode string
            var length = 0
            event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: nil)
            if length > 0 {
                var chars = [UniChar](repeating: 0, count: length)
                event.keyboardGetUnicodeString(maxStringLength: length, actualStringLength: &length, unicodeString: &chars)
                let str = String(utf16CodeUnits: chars, count: length)
                
                for scalar in str.unicodeScalars {
                    if CharacterSet.alphanumerics.contains(scalar) || CharacterSet.punctuationCharacters.contains(scalar) {
                        typedBuffer.append(Character(scalar))
                    } else if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                        typedBuffer.append(" ")
                    }
                }
                
                // Keep buffer bounded
                if typedBuffer.count > maxBufferLength {
                    typedBuffer = String(typedBuffer.suffix(maxBufferLength))
                }
            }
        }
    }
    
    /// Extracts the trailing token from the typing buffer and checks if it matches any shortcut.
    public func resolveShortcutBeforeCursor() -> (token: String, shortcut: TextShortcut)? {
        guard !typedBuffer.isEmpty else { return nil }
        
        // Find trailing word token (alphanumeric sequence ending at cursor)
        let token = extractTrailingToken(from: typedBuffer)
        guard !token.isEmpty else { return nil }
        
        if let shortcut = TextShortcutStore.shared.lookup(token: token) {
            return (token, shortcut)
        }
        
        return nil
    }
    
    /// Extracts the word token immediately preceding the cursor.
    /// Handles word boundaries, preceding spaces, and punctuation gracefully.
    public func extractTrailingToken(from text: String) -> String {
        var token = ""
        for char in text.reversed() {
            if char.isLetter || char.isNumber || char == "_" || char == "-" {
                token.append(char)
            } else {
                break
            }
        }
        return String(token.reversed())
    }
    
    // Testing helper
    public func simulateTyping(_ text: String) {
        typedBuffer = text
    }
}
