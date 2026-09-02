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
        let assetStorage = ShortcutAssetStorage.shared
        
        // Helper to create test image data
        func makeTestImageData(width: Int = 40, height: Int = 40) -> Data {
            let image = NSImage(size: NSSize(width: width, height: height))
            image.lockFocus()
            NSColor.systemBlue.setFill()
            NSRect(x: 0, y: 0, width: width, height: height).fill()
            image.unlockFocus()
            let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
            return rep.representation(using: .png, properties: [:])!
        }
        
        // ────────────────────────────────────────────────────────────────
        // TEST 1: Model creation and normalizedKey (Text & Image)
        // ────────────────────────────────────────────────────────────────
        let textItem = TextShortcut(shortcut: "Myemail", type: .text, textContent: "name@example.com")
        check(textItem.shortcut == "Myemail", "TEST 1: Shortcut text must be preserved")
        check(textItem.type == .text, "TEST 1: Shortcut type must be .text")
        check(textItem.textContent == "name@example.com", "TEST 1: textContent must be preserved")
        check(textItem.normalizedKey == "myemail", "TEST 1: normalizedKey must be lowercase")
        
        let imageItem = TextShortcut(shortcut: "sign", type: .image, imageAsset: "test-asset.png", imageName: "signature.png")
        check(imageItem.shortcut == "sign", "TEST 1: Image shortcut must be preserved")
        check(imageItem.type == .image, "TEST 1: Shortcut type must be .image")
        check(imageItem.imageAsset == "test-asset.png", "TEST 1: imageAsset must match")
        check(imageItem.imageName == "signature.png", "TEST 1: imageName must match")
        check(imageItem.normalizedKey == "sign", "TEST 1: normalizedKey must be 'sign'")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 2: Case-Insensitive Matching (Text & Image)
        // ────────────────────────────────────────────────────────────────
        store.resetForTesting(shortcuts: [
            TextShortcut(shortcut: "Myemail", type: .text, textContent: "name@example.com"),
            TextShortcut(shortcut: "Addr", type: .text, textContent: "123 ABC Street, City\nCountry"),
            TextShortcut(shortcut: "sign", type: .image, imageAsset: "sig.png", imageName: "my_sig.png")
        ])
        
        let textTestCases = ["myemail", "MYEMAIL", "Myemail", "MyEmail", "MYEMail", "mYeMaIl"]
        for testCase in textTestCases {
            let match = store.lookup(token: testCase)
            check(match != nil, "TEST 2: lookup for '\(testCase)' must succeed")
            check(match?.type == .text, "TEST 2: type must be .text")
            check(match?.textContent == "name@example.com", "TEST 2: replacement for '\(testCase)' must be exact")
        }
        
        let imageTestCases = ["sign", "SIGN", "Sign", "sIgN"]
        for testCase in imageTestCases {
            let match = store.lookup(token: testCase)
            check(match != nil, "TEST 2: image lookup for '\(testCase)' must succeed")
            check(match?.type == .image, "TEST 2: type must be .image")
            check(match?.imageAsset == "sig.png", "TEST 2: imageAsset must match")
        }
        
        // Non-matching token returns nil
        let nonMatch = store.lookup(token: "unknown_token")
        check(nonMatch == nil, "TEST 2: Non-matching token must return nil")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 3: Validation — Empty shortcut and whitespace rejected
        // ────────────────────────────────────────────────────────────────
        let emptyValidation = TextShortcut.validate(
            shortcut: "   ",
            type: .text,
            textContent: "test",
            imageAsset: nil,
            existing: store.shortcuts
        )
        check(emptyValidation != nil, "TEST 3: Empty shortcut must be rejected")
        
        let spaceValidation = TextShortcut.validate(
            shortcut: "my email",
            type: .text,
            textContent: "test",
            imageAsset: nil,
            existing: store.shortcuts
        )
        check(spaceValidation != nil, "TEST 3: Shortcut containing spaces must be rejected")
        
        let missingImageValidation = TextShortcut.validate(
            shortcut: "logo",
            type: .image,
            textContent: nil,
            imageAsset: nil,
            existing: store.shortcuts
        )
        check(missingImageValidation != nil, "TEST 3: Image shortcut without image asset must be rejected")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 4: Validation — Duplicate shortcut rejected case-insensitively
        // ────────────────────────────────────────────────────────────────
        let dupValidation1 = TextShortcut.validate(
            shortcut: "myemail",
            type: .text,
            textContent: "other@gmail.com",
            imageAsset: nil,
            existing: store.shortcuts
        )
        check(dupValidation1 != nil, "TEST 4: Duplicate lowercase shortcut must be rejected")
        
        let dupValidation2 = TextShortcut.validate(
            shortcut: "SIGN",
            type: .image,
            textContent: nil,
            imageAsset: "new_sig.png",
            existing: store.shortcuts
        )
        check(dupValidation2 != nil, "TEST 4: Duplicate uppercase shortcut against image must be rejected")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 5: ShortcutAssetStorage operations
        // ────────────────────────────────────────────────────────────────
        let testData = makeTestImageData()
        guard let savedAsset = assetStorage.saveImageData(testData, originalName: "test_logo.png") else {
            check(false, "TEST 5: Failed to save test image data")
            return
        }
        
        let loadedData = assetStorage.loadImageData(assetFilename: savedAsset.assetFilename)
        check(loadedData != nil, "TEST 5: Loaded image data must not be nil")
        check(loadedData?.count == testData.count, "TEST 5: Loaded data count must match saved data")
        
        let thumbnail = assetStorage.loadThumbnailImage(assetFilename: savedAsset.assetFilename)
        check(thumbnail != nil, "TEST 5: Thumbnail image must be loadable")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 6: Store CRUD & Shared Asset Protection
        // ────────────────────────────────────────────────────────────────
        // Add Image shortcut
        let addImgRes = store.addImageShortcut(shortcut: "brandlogo", assetFilename: savedAsset.assetFilename, originalName: "test_logo.png")
        check(addImgRes.success, "TEST 6: addImageShortcut must succeed")
        check(store.lookup(token: "BRANDLOGO")?.imageAsset == savedAsset.assetFilename, "TEST 6: Lookup must return correct asset")
        
        // Add second shortcut referencing the SAME asset
        let addSharedRes = store.addImageShortcut(shortcut: "secondarylogo", assetFilename: savedAsset.assetFilename, originalName: "test_logo.png")
        check(addSharedRes.success, "TEST 6: addImageShortcut for shared asset must succeed")
        
        // Delete first shortcut — asset MUST still exist because second shortcut references it
        let firstItem = store.lookup(token: "brandlogo")!
        store.delete(id: firstItem.id)
        check(store.lookup(token: "brandlogo") == nil, "TEST 6: Deleted shortcut must be gone")
        check(assetStorage.loadImageData(assetFilename: savedAsset.assetFilename) != nil, "TEST 6: Shared asset must NOT be deleted while second shortcut exists")
        
        // Delete second shortcut — asset should now be cleaned up
        let secondItem = store.lookup(token: "secondarylogo")!
        store.delete(id: secondItem.id)
        check(store.lookup(token: "secondarylogo") == nil, "TEST 6: Second shortcut must be gone")
        check(assetStorage.loadImageData(assetFilename: savedAsset.assetFilename) == nil, "TEST 6: Unreferenced asset should be deleted from disk")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 7: Trailing Token Extraction & Word Boundaries
        // ────────────────────────────────────────────────────────────────
        let monitor = TextShortcutMonitor.shared
        
        let token1 = monitor.extractTrailingToken(from: "Please see sign")
        check(token1 == "sign", "TEST 7: Trailing token after space should be 'sign' (got '\(token1)')")
        
        let token2 = monitor.extractTrailingToken(from: "my_signature_key")
        check(token2 == "my_signature_key", "TEST 7: Token with underscore should be extracted (got '\(token2)')")
        
        let token3 = monitor.extractTrailingToken(from: "image-shortcut")
        check(token3 == "image-shortcut", "TEST 7: Token with hyphen should be extracted (got '\(token3)')")
        
        let token4 = monitor.extractTrailingToken(from: "sign,")
        check(token4 == "", "TEST 7: Trailing punctuation should yield empty token (got '\(token4)')")
        
        print("✅ TextShortcutTests passed successfully!")
    }
}
