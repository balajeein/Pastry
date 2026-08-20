import XCTest
@testable import PastryCore

final class ClipboardTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Reset limits to standard defaults
        UserDefaults.standard.set(20, forKey: "textHistoryLimit")
        UserDefaults.standard.set(10, forKey: "imageHistoryLimit")
        UserDefaults.standard.set(10, forKey: "otherHistoryLimit")
        ClipboardStore.shared.clearHistory()
        
        // Wait briefly for async operations to complete
        let expectation = XCTestExpectation(description: "Clear Store")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testDeduplication() {
        let store = ClipboardStore.shared
        
        let item1 = ClipboardItem(type: .text, textContent: "Hello Balajee", displayTitle: "Hello Balajee")
        let item2 = ClipboardItem(type: .text, textContent: "Hello Balajee", displayTitle: "Hello Balajee")
        
        store.forceAddForTest(item: item1)
        store.forceAddForTest(item: item2)
        
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.textContent, "Hello Balajee")
    }
    
    func testHistoryLimits() {
        let store = ClipboardStore.shared
        
        // Override limit for test case
        UserDefaults.standard.set(3, forKey: "textHistoryLimit")
        
        let item1 = ClipboardItem(type: .text, textContent: "Text 1", displayTitle: "Text 1")
        let item2 = ClipboardItem(type: .text, textContent: "Text 2", displayTitle: "Text 2")
        let item3 = ClipboardItem(type: .text, textContent: "Text 3", displayTitle: "Text 3")
        let item4 = ClipboardItem(type: .text, textContent: "Text 4", displayTitle: "Text 4")
        
        store.forceAddForTest(item: item1)
        store.forceAddForTest(item: item2)
        store.forceAddForTest(item: item3)
        store.forceAddForTest(item: item4)
        
        XCTAssertEqual(store.items.count, 3)
        // Order should be Text 4, Text 3, Text 2 (newest first, oldest evicted)
        XCTAssertEqual(store.items[0].textContent, "Text 4")
        XCTAssertEqual(store.items[1].textContent, "Text 3")
        XCTAssertEqual(store.items[2].textContent, "Text 2")
    }
    
    func testSearch() {
        let store = ClipboardStore.shared
        
        let item1 = ClipboardItem(type: .text, textContent: "npm install express", displayTitle: "npm install express")
        let item2 = ClipboardItem(type: .text, textContent: "github.com/example", displayTitle: "github.com/example")
        let item3 = ClipboardItem(type: .text, textContent: "hello world", displayTitle: "hello world")
        
        store.forceAddForTest(item: item1)
        store.forceAddForTest(item: item2)
        store.forceAddForTest(item: item3)
        
        let vm = ClipboardPanelViewModel()
        
        // Test query match
        vm.searchText = "npm"
        XCTAssertEqual(vm.filteredItems.count, 1)
        XCTAssertEqual(vm.filteredItems.first?.textContent, "npm install express")
        
        // Test case insensitive match
        vm.searchText = "GITHUB"
        XCTAssertEqual(vm.filteredItems.count, 1)
        XCTAssertEqual(vm.filteredItems.first?.textContent, "github.com/example")
        
        // Test empty/non match
        vm.searchText = "nonexistent"
        XCTAssertTrue(vm.filteredItems.isEmpty)
    }
    
    func testPersistence() {
        let store = ClipboardStore.shared
        
        let item = ClipboardItem(type: .text, textContent: "Persisted item", displayTitle: "Persisted item")
        store.forceAddForTest(item: item)
        store.saveHistory()
        
        let saveExpectation = XCTestExpectation(description: "Save finish")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            saveExpectation.fulfill()
        }
        wait(for: [saveExpectation], timeout: 1.0)
        
        store.clearHistory()
        
        let clearExpectation = XCTestExpectation(description: "Clear finish")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            clearExpectation.fulfill()
        }
        wait(for: [clearExpectation], timeout: 1.0)
        
        XCTAssertEqual(store.items.count, 0)
        
        store.loadHistory()
        
        let loadExpectation = XCTestExpectation(description: "Load finish")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            loadExpectation.fulfill()
        }
        wait(for: [loadExpectation], timeout: 1.0)
        
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.textContent, "Persisted item")
    }
}
