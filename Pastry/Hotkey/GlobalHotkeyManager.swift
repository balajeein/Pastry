import Carbon
import Cocoa
import Foundation

public class GlobalHotkeyManager {
    public static let shared = GlobalHotkeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    public var onTrigger: (() -> Void)?
    
    private init() {
        setupEventHandler()
    }
    
    private func setupEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, event, userData) -> OSStatus in
                guard let event = event else { return OSStatus(eventNotHandledErr) }
                
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                if status == noErr && hotKeyID.id == 1 {
                    // Trigger the hotkey action
                    DispatchQueue.main.async {
                        GlobalHotkeyManager.shared.onTrigger?()
                    }
                    return noErr
                }
                
                return OSStatus(eventNotHandledErr)
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )
        
        if status != noErr {
            // Failed to register event handler
        }
    }
    
    public func registerDefaultHotkey() -> Bool {
        // Default: Command + Shift + V
        // Key code for 'V' is 9
        // Modifiers: cmdKey (256) | shiftKey (512) = 768
        return registerHotkey(keyCode: 9, modifiers: UInt32(cmdKey | shiftKey))
    }
    
    public func registerHotkey(keyCode: UInt32, modifiers: UInt32) -> Bool {
        unregisterHotkey()
        
        // Use a unique signature for Pastry hotkeys (e.g. 'PSTR' -> 0x50535452)
        let signature = OSType(0x50535452)
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        var ref: EventHotKeyRef?
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        
        if status == noErr {
            hotKeyRef = ref
            return true
        } else {
            return false
        }
    }
    
    public func unregisterHotkey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
    
    // Helper to format hotkey modifiers + keycode into a display string (e.g. "⌘⇧V")
    public static func getHotkeyString(keyCode: UInt32, modifiers: UInt32) -> String {
        var str = ""
        if (modifiers & UInt32(controlKey)) != 0 { str += "⌃" }
        if (modifiers & UInt32(optionKey)) != 0 { str += "⌥" }
        if (modifiers & UInt32(shiftKey)) != 0 { str += "⇧" }
        if (modifiers & UInt32(cmdKey)) != 0 { str += "⌘" }
        
        str += getKeyName(keyCode: keyCode)
        return str
    }
    
    // Converts Carbon modifier flags into AppKit's NSEvent.ModifierFlags
    public static func keyEquivalentModifierMask(from carbonModifiers: UInt32) -> NSEvent.ModifierFlags {
        var mask: NSEvent.ModifierFlags = []
        if (carbonModifiers & UInt32(cmdKey)) != 0 { mask.insert(.command) }
        if (carbonModifiers & UInt32(shiftKey)) != 0 { mask.insert(.shift) }
        if (carbonModifiers & UInt32(optionKey)) != 0 { mask.insert(.option) }
        if (carbonModifiers & UInt32(controlKey)) != 0 { mask.insert(.control) }
        return mask
    }
    
    // Converts a virtual keycode to an AppKit keyEquivalent string
    public static func getKeyEquivalent(keyCode: UInt32) -> String {
        switch keyCode {
        case 36: return "\r"        // Return
        case 48: return "\t"        // Tab
        case 49: return " "         // Space
        case 51: return "\u{0008}"  // Backspace / Delete
        case 53: return "\u{001b}"  // Escape
        case 71: return "\u{001b}"  // Clear
        case 76: return "\u{0003}"  // Enter (Keypad)
        case 117: return String(utf16CodeUnits: [unichar(NSDeleteFunctionKey)], count: 1) // Forward Delete
        case 123: return String(utf16CodeUnits: [unichar(NSLeftArrowFunctionKey)], count: 1)
        case 124: return String(utf16CodeUnits: [unichar(NSRightArrowFunctionKey)], count: 1)
        case 125: return String(utf16CodeUnits: [unichar(NSDownArrowFunctionKey)], count: 1)
        case 126: return String(utf16CodeUnits: [unichar(NSUpArrowFunctionKey)], count: 1)
        case 122: return String(utf16CodeUnits: [unichar(NSF1FunctionKey)], count: 1)
        case 120: return String(utf16CodeUnits: [unichar(NSF2FunctionKey)], count: 1)
        case 99:  return String(utf16CodeUnits: [unichar(NSF3FunctionKey)], count: 1)
        case 118: return String(utf16CodeUnits: [unichar(NSF4FunctionKey)], count: 1)
        case 96:  return String(utf16CodeUnits: [unichar(NSF5FunctionKey)], count: 1)
        case 97:  return String(utf16CodeUnits: [unichar(NSF6FunctionKey)], count: 1)
        case 98:  return String(utf16CodeUnits: [unichar(NSF7FunctionKey)], count: 1)
        case 100: return String(utf16CodeUnits: [unichar(NSF8FunctionKey)], count: 1)
        case 101: return String(utf16CodeUnits: [unichar(NSF9FunctionKey)], count: 1)
        case 109: return String(utf16CodeUnits: [unichar(NSF10FunctionKey)], count: 1)
        case 103: return String(utf16CodeUnits: [unichar(NSF11FunctionKey)], count: 1)
        case 111: return String(utf16CodeUnits: [unichar(NSF12FunctionKey)], count: 1)
        default:
            if let char = getUnicodeCharacter(from: UInt16(keyCode)) {
                return char.lowercased()
            }
            if let fallback = standardKeyString(for: keyCode) {
                return fallback.lowercased()
            }
            return ""
        }
    }
    
    private static func getKeyName(keyCode: UInt32) -> String {
        switch keyCode {
        case 9: return "V"
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 53: return "⎋"
        case 71: return "Clear"
        case 76: return "⌤"
        case 117: return "⌦"
        case 122: return "F1"
        case 120: return "F2"
        case 99:  return "F3"
        case 118: return "F4"
        case 96:  return "F5"
        case 97:  return "F6"
        case 98:  return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            if let char = getUnicodeCharacter(from: UInt16(keyCode)) {
                let trimmed = char.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed.uppercased()
                }
            }
            if let fallback = standardKeyString(for: keyCode) {
                return fallback.uppercased()
            }
            return "Key \(keyCode)"
        }
    }
    
    private static func standardKeyString(for keyCode: UInt32) -> String? {
        switch keyCode {
        case 0: return "a"
        case 1: return "s"
        case 2: return "d"
        case 3: return "f"
        case 4: return "h"
        case 5: return "g"
        case 6: return "z"
        case 7: return "x"
        case 8: return "c"
        case 9: return "v"
        case 11: return "b"
        case 12: return "q"
        case 13: return "w"
        case 14: return "e"
        case 15: return "r"
        case 16: return "y"
        case 17: return "t"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "o"
        case 32: return "u"
        case 33: return "["
        case 34: return "i"
        case 35: return "p"
        case 37: return "l"
        case 38: return "j"
        case 39: return "'"
        case 40: return "k"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "n"
        case 46: return "m"
        case 47: return "."
        case 50: return "`"
        default: return nil
        }
    }
    
    private static func getUnicodeCharacter(from keyCode: UInt16) -> String? {
        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        guard let layoutDataRef = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        
        let layoutData = unsafeBitCast(layoutDataRef, to: CFData.self)
        let rawLayoutData = CFDataGetBytePtr(layoutData)!
        
        var deadKeys: UInt32 = 0
        var unicodeString = [UniChar](repeating: 0, count: 4)
        var actualStringLength = 0
        
        let status = rawLayoutData.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { layoutPtr in
            UCKeyTranslate(
            layoutPtr,
            keyCode,
            UInt16(kUCKeyActionDown),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysMask),
            &deadKeys,
            4,
            &actualStringLength,
            &unicodeString
        )
        }
        
        guard status == noErr && actualStringLength > 0 else { return nil }
        return String(utf16CodeUnits: unicodeString, count: actualStringLength)
    }
}
