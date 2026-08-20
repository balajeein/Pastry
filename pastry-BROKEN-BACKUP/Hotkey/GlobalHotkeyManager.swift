import Carbon
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
    
    private static func getKeyName(keyCode: UInt32) -> String {
        switch keyCode {
        case 9: return "V"
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 53: return "⎋"
        default:
            // Generic fallback using TISGetInputSource/UCKeyTranslate if required
            // but for simplicity, we provide a basic lookup or standard characters.
            if let char = getUnicodeCharacter(from: UInt16(keyCode)) {
                return char.uppercased()
            }
            return "Key \(keyCode)"
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
