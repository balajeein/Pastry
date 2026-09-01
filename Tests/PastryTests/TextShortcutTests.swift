import Foundation
import AppKit

public struct TextShortcutTests {
    public static func runAll() {
        print("🧪 Running TextShortcutTests...")
        
        func check(_ condition: Bool, _ msg: String, line: Int = #line) {
            if !condition {
                print("❌ FAIL [line \(line)]: \(msg)")
                exit(1)
            }
        }
        
        let store = TextShortcutStore.shared
        
        // ────────────────────────────────────────────────────────────────
        // TEST 1: Model creation and normalizedKey
        // ────────────────────────────────────────────────────────────────
        let item1 = TextShortcut(shortcut: "Myemail", replacement: "balajee@gmail.com")
        check(item1.shortcut == "Myemail", "TEST 1: Shortcut text must be preserved")
        check(item1.replacement == "balajee@gmail.com", "TEST 1: Replacement text must be preserved")
        check(item1.normalizedKey == "myemail", "TEST 1: normalizedKey must be lowercase")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 2: Case-Insensitive Matching
        // ────────────────────────────────────────────────────────────────
        store.resetForTesting(shortcuts: [
            TextShortcut(shortcut: "Myemail", replacement: "balajee@gmail.com"),
            TextShortcut(shortcut: "Addr", replacement: "123 ABC Street, Chennai\nIndia"),
            TextShortcut(shortcut: "ph", replacement: "+91 98765 43210")
        ])
        
        let testCases = ["myemail", "MYEMAIL", "Myemail", "MyEmail", "MYEMail", "mYeMaIl"]
        for testCase in testCases {
            let match = store.lookup(token: testCase)
            check(match != nil, "TEST 2: lookup for '\(testCase)' must succeed")
            check(match?.replacement == "balajee@gmail.com", "TEST 2: replacement for '\(testCase)' must be exact")
        }
        
        // Multiline replacement preservation
        let addrMatch = store.lookup(token: "addr")
        check(addrMatch?.replacement == "123 ABC Street, Chennai\nIndia", "TEST 2: Multiline replacement must be preserved exactly")
        
        // Non-matching token returns nil
        let nonMatch = store.lookup(token: "unknown_token")
        check(nonMatch == nil, "TEST 2: Non-matching token must return nil")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 3: Validation — Empty shortcut rejected
        // ────────────────────────────────────────────────────────────────
        let emptyValidation = TextShortcut.validate(shortcut: "   ", replacement: "test", existing: store.shortcuts)
        check(emptyValidation != nil, "TEST 3: Empty shortcut must be rejected")
        
        let spaceValidation = TextShortcut.validate(shortcut: "my email", replacement: "test", existing: store.shortcuts)
        check(spaceValidation != nil, "TEST 3: Shortcut containing spaces must be rejected")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 4: Validation — Duplicate shortcut rejected case-insensitively
        // ────────────────────────────────────────────────────────────────
        let dupValidation1 = TextShortcut.validate(shortcut: "myemail", replacement: "other@gmail.com", existing: store.shortcuts)
        check(dupValidation1 != nil, "TEST 4: Duplicate lowercase shortcut must be rejected")
        
        let dupValidation2 = TextShortcut.validate(shortcut: "MYEMAIL", replacement: "other@gmail.com", existing: store.shortcuts)
        check(dupValidation2 != nil, "TEST 4: Duplicate uppercase shortcut must be rejected")
        
        // Editing existing shortcut with the same name is allowed
        let existingItem = store.shortcuts.first(where: { $0.normalizedKey == "myemail" })!
        let editValidation = TextShortcut.validate(shortcut: "MyEmail", replacement: "updated@gmail.com", existing: store.shortcuts, editingId: existingItem.id)
        check(editValidation == nil, "TEST 4: Editing existing shortcut should allow keeping the same name")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 5: Trailing Token Extraction & Word Boundaries
        // ────────────────────────────────────────────────────────────────
        let monitor = TextShortcutMonitor.shared
        
        let token1 = monitor.extractTrailingToken(from: "Hello Myemail")
        check(token1 == "Myemail", "TEST 5: Trailing token after space should be 'Myemail' (got '\(token1)')")
        
        let token2 = monitor.extractTrailingToken(from: "Myemail")
        check(token2 == "Myemail", "TEST 5: Single token should be 'Myemail' (got '\(token2)')")
        
        let token3 = monitor.extractTrailingToken(from: "Please contact me at my-shortcut")
        check(token3 == "my-shortcut", "TEST 5: Token with hyphen should be extracted (got '\(token3)')")
        
        let token4 = monitor.extractTrailingToken(from: "prefix_addr")
        check(token4 == "prefix_addr", "TEST 5: Token with underscore should be extracted (got '\(token4)')")
        
        let token5 = monitor.extractTrailingToken(from: "Hello Myemail,")
        check(token5 == "", "TEST 5: Trailing punctuation should yield empty word token (got '\(token5)')")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 6: Trigger Resolution Before Cursor
        // ────────────────────────────────────────────────────────────────
        monitor.simulateTyping("Hello MYEMAIL")
        let resolved = monitor.resolveShortcutBeforeCursor()
        check(resolved != nil, "TEST 6: resolveShortcutBeforeCursor must succeed for 'Hello MYEMAIL'")
        check(resolved?.token == "MYEMAIL", "TEST 6: matched token must be 'MYEMAIL'")
        check(resolved?.shortcut.replacement == "balajee@gmail.com", "TEST 6: replacement must be 'balajee@gmail.com'")
        
        monitor.simulateTyping("Random text without shortcut")
        let unresolved = monitor.resolveShortcutBeforeCursor()
        check(unresolved == nil, "TEST 6: unresolved text must return nil")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 7: Store CRUD Operations
        // ────────────────────────────────────────────────────────────────
        let addRes = store.add(shortcut: "custom_key", replacement: "Custom Value 123")
        check(addRes.success, "TEST 7: Adding valid shortcut must succeed")
        check(store.lookup(token: "CUSTOM_KEY")?.replacement == "Custom Value 123", "TEST 7: Newly added shortcut must be lookable")
        
        let addedItem = store.lookup(token: "custom_key")!
        let updateRes = store.update(id: addedItem.id, shortcut: "custom_key_v2", replacement: "Updated Value")
        check(updateRes.success, "TEST 7: Updating shortcut must succeed")
        check(store.lookup(token: "custom_key_v2")?.replacement == "Updated Value", "TEST 7: Updated shortcut must have new value")
        
        store.delete(id: addedItem.id)
        check(store.lookup(token: "custom_key_v2") == nil, "TEST 7: Deleted shortcut must no longer be found")
        
        print("✅ TextShortcutTests passed successfully!")
    }
}
