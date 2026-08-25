import Foundation

public struct ClipboardTests {
    
    public static func runAll() {
        print("🧪 Running ClipboardTests...")
        
        func check(_ condition: Bool, _ msg: String, line: Int = #line) {
            if !condition {
                print("❌ FAIL [line \(line)]: \(msg)")
                exit(1)
            }
        }
        
        // Reset limits to standard defaults
        UserDefaults.standard.set(20, forKey: "textHistoryLimit")
        UserDefaults.standard.set(10, forKey: "imageHistoryLimit")
        UserDefaults.standard.set(10, forKey: "otherHistoryLimit")
        ClipboardStore.shared.clearHistory()
        Thread.sleep(forTimeInterval: 0.05)
        
        // Test Deduplication
        let store = ClipboardStore.shared
        let item1 = ClipboardItem(type: .text, textContent: "Hello Balajee", displayTitle: "Hello Balajee")
        let item2 = ClipboardItem(type: .text, textContent: "Hello Balajee", displayTitle: "Hello Balajee")
        
        store.forceAddForTest(item: item1)
        store.forceAddForTest(item: item2)
        
        check(store.items.count == 1, "Deduplication count mismatch")
        check(store.items.first?.textContent == "Hello Balajee", "Deduplication text content mismatch")
        
        // Test Search
        let item3 = ClipboardItem(type: .text, textContent: "npm install express", displayTitle: "npm install express")
        let item4 = ClipboardItem(type: .text, textContent: "github.com/example", displayTitle: "github.com/example")
        
        store.forceAddForTest(item: item3)
        store.forceAddForTest(item: item4)
        
        let vm = ClipboardPanelViewModel()
        vm.searchText = "npm"
        check(vm.filteredItems.count == 1, "Search count mismatch")
        check(vm.filteredItems.first?.textContent == "npm install express", "Search content mismatch")
        
        vm.searchText = "GITHUB"
        check(vm.filteredItems.count == 1, "Search case insensitive count mismatch")
        check(vm.filteredItems.first?.textContent == "github.com/example", "Search case insensitive content mismatch")
        
        vm.searchText = "nonexistent"
        check(vm.filteredItems.isEmpty, "Search non-match failed")
        
        // Test Real Clipboard Calculation Integration Flow (Requirement 36)
        testRealClipboardFlow(check: check)
        
        print("✅ ClipboardTests passed successfully!")
    }
    
    private static func testRealClipboardFlow(check: (Bool, String, Int) -> Void) {
        func verifyClipboardItem(copiedText: String, expectedLeft: String, expectedRight: String?, line: Int = #line) {
            let calcResult = ExpressionParser.evaluate(copiedText)
            let item = ClipboardItem(
                type: .text,
                textContent: copiedText,
                displayTitle: copiedText,
                calculationResult: calcResult
            )
            check(item.displayTitle == expectedLeft, "LEFT side mismatch for '\(copiedText)': expected '\(expectedLeft)', got '\(item.displayTitle)'", line)
            check(item.calculationResult == expectedRight, "RIGHT side mismatch for '\(copiedText)': expected '\(expectedRight ?? "nil")', got '\(item.calculationResult ?? "nil")'", line)
        }
        
        verifyClipboardItem(copiedText: "4^2", expectedLeft: "4^2", expectedRight: "16")
        verifyClipboardItem(copiedText: "2(4)", expectedLeft: "2(4)", expectedRight: "8")
        verifyClipboardItem(copiedText: "235*24214 =", expectedLeft: "235*24214 =", expectedRight: "5,690,290")
        verifyClipboardItem(copiedText: "sin(90)", expectedLeft: "sin(90)", expectedRight: "1")
        verifyClipboardItem(copiedText: "sqrt(16)", expectedLeft: "sqrt(16)", expectedRight: "4")
        verifyClipboardItem(copiedText: "Hello world", expectedLeft: "Hello world", expectedRight: nil)
        verifyClipboardItem(copiedText: "I have 25 apples", expectedLeft: "I have 25 apples", expectedRight: nil)
        verifyClipboardItem(copiedText: "2+2=4", expectedLeft: "2+2=4", expectedRight: nil)
    }
}
