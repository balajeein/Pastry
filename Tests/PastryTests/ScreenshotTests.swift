import Foundation
import AppKit

public struct ScreenshotTests {
    public static func runAll() {
        print("🧪 Running ScreenshotTests...")
        
        func check(_ condition: Bool, _ msg: String, line: Int = #line) {
            if !condition {
                print("❌ FAIL [line \(line)]: \(msg)")
                exit(1)
            }
        }
        
        func tickRunLoop(for duration: TimeInterval) {
            RunLoop.current.run(until: Date().addingTimeInterval(duration))
        }
        
        // 1. Screenshot Directory Resolution Test
        let dir = ScreenshotMonitor.getScreenshotDirectory()
        check(FileManager.default.fileExists(atPath: dir.path), "Screenshot directory must exist")
        
        // 2. Screenshot File Detection & Unique Thumbnail Ingestion Test
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tmpDir)
        }
        
        // Clear history and tracking state for fresh test execution
        ClipboardStore.shared.clearHistory()
        ScreenshotMonitor.shared.resetTrackingForTest()
        tickRunLoop(for: 0.1)
        
        // Screenshot A (Unique dimensions 105x105)
        let imgA = NSImage(size: NSSize(width: 105, height: 105))
        imgA.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 105, height: 105).fill()
        imgA.unlockFocus()
        
        guard let tiffA = imgA.tiffRepresentation,
              let repA = NSBitmapImageRep(data: tiffA),
              let pngDataA = repA.representation(using: .png, properties: [:]) else {
            print("❌ FAIL: Could not generate synthetic PNG data A")
            exit(1)
        }
        
        let screenshotURL_A = tmpDir.appendingPathComponent("Screenshot 2026-08-25 at 10.00.00.png")
        try? pngDataA.write(to: screenshotURL_A)
        
        let initialItemCount = ClipboardStore.shared.items.count
        
        ScreenshotMonitor.shared.scanDirectorySync(directory: tmpDir, timeWindow: 120.0)
        tickRunLoop(for: 0.3)
        
        let itemsAfterA = ClipboardStore.shared.items
        check(itemsAfterA.count == initialItemCount + 1, "Screenshot A should be ingested into ClipboardStore")
        
        guard let itemA = itemsAfterA.first else {
            print("❌ FAIL: Item A not found")
            exit(1)
        }
        check(itemA.type == .image, "Item A type must be .image")
        check(itemA.storagePath != nil, "Item A must have storagePath")
        
        // Screenshot B (Unique dimensions 215x215 - different content & hash)
        let imgB = NSImage(size: NSSize(width: 215, height: 215))
        imgB.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 215, height: 215).fill()
        imgB.unlockFocus()
        
        guard let tiffB = imgB.tiffRepresentation,
              let repB = NSBitmapImageRep(data: tiffB),
              let pngDataB = repB.representation(using: .png, properties: [:]) else {
            print("❌ FAIL: Could not generate synthetic PNG data B")
            exit(1)
        }
        
        let screenshotURL_B = tmpDir.appendingPathComponent("Screenshot 2026-08-25 at 10.00.05.png")
        try? pngDataB.write(to: screenshotURL_B)
        
        ScreenshotMonitor.shared.scanDirectorySync(directory: tmpDir, timeWindow: 120.0)
        tickRunLoop(for: 0.3)
        
        let itemsAfterB = ClipboardStore.shared.items
        check(itemsAfterB.count == initialItemCount + 2, "Screenshot B should also be ingested separately")
        
        let topItemB = itemsAfterB[0]
        let nextItemA = itemsAfterB[1]
        
        check(topItemB.storagePath != nextItemA.storagePath, "Screenshot A and Screenshot B MUST have different storage paths")
        check(topItemB.contentHash != nextItemA.contentHash, "Screenshot A and Screenshot B MUST have different content hashes")
        
        // Verify thumbnail files exist uniquely on disk
        if let pathB = topItemB.storagePath, let pathA = nextItemA.storagePath {
            check(ImageStorage.shared.loadThumbnail(path: pathB) != nil, "Thumbnail B must exist")
            check(ImageStorage.shared.loadThumbnail(path: pathA) != nil, "Thumbnail A must exist")
        }
        
        // 3. Deduplication Test (re-scanning directory)
        ScreenshotMonitor.shared.scanDirectorySync(directory: tmpDir, timeWindow: 120.0)
        tickRunLoop(for: 0.2)
        check(ClipboardStore.shared.items.count == initialItemCount + 2, "Duplicate rescanning must not create new entries")
        
        // 4. Non-Screenshot File Ignore Test
        let textFileURL = tmpDir.appendingPathComponent("document.txt")
        try? "hello world".data(using: .utf8)?.write(to: textFileURL)
        
        ScreenshotMonitor.shared.scanDirectorySync(directory: tmpDir, timeWindow: 120.0)
        tickRunLoop(for: 0.2)
        check(ClipboardStore.shared.items.count == initialItemCount + 2, "Non-screenshot file document.txt should be ignored")
        
        print("✅ ScreenshotTests passed successfully!")
    }
}
