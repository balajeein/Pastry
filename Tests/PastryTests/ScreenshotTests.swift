import Foundation
import AppKit
import CryptoKit

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
            let limit = Date().addingTimeInterval(duration)
            while Date() < limit {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            }
        }
        
        // 1. Screenshot Directory Resolution Test
        let dir = ScreenshotMonitor.getScreenshotDirectory()
        check(FileManager.default.fileExists(atPath: dir.path), "Screenshot directory must exist")
        
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tmpDir)
            SettingsManager.shared.isScreenshotTrackingPaused = false
        }
        
        // Setup clean state
        ClipboardStore.shared.clearHistory()
        tickRunLoop(for: 0.3)
        ScreenshotMonitor.shared.resetTrackingForTest()
        SettingsManager.shared.isScreenshotTrackingPaused = false
        tickRunLoop(for: 0.3)
        
        // Helper to generate unique PNG data and its SHA-256 hash
        func makePNG(width: Int, height: Int, color: NSColor) -> (data: Data, hash: String) {
            let img = NSImage(size: NSSize(width: width, height: height))
            img.lockFocus()
            color.setFill()
            NSRect(x: 0, y: 0, width: width, height: height).fill()
            let str = UUID().uuidString as NSString
            str.draw(at: NSPoint(x: 5, y: 5), withAttributes: [.foregroundColor: NSColor.white])
            img.unlockFocus()
            let tiff = img.tiffRepresentation!
            let rep = NSBitmapImageRep(data: tiff)!
            let png = rep.representation(using: .png, properties: [:])!
            let digest = SHA256.hash(data: png)
            let hashStr = digest.map { String(format: "%02x", $0) }.joined()
            return (png, hashStr)
        }
        
        let (pngDataA, hashA) = makePNG(width: 105, height: 105, color: .red)
        let (pngDataB, hashB) = makePNG(width: 215, height: 215, color: .blue)
        let (pngDataC, hashC) = makePNG(width: 315, height: 315, color: .green)
        let (pngDataD, hashD) = makePNG(width: 415, height: 415, color: .yellow)
        
        // ────────────────────────────────────────────────────────────────
        // TEST 1: Tracking ON -> Screenshot A -> Appears in Pastry
        // ────────────────────────────────────────────────────────────────
        let urlA = tmpDir.appendingPathComponent("Screenshot 2026-08-25 at 10.00.01.png")
        try? pngDataA.write(to: urlA)
        
        ScreenshotMonitor.shared.scanDirectorySync(directory: tmpDir)
        tickRunLoop(for: 0.5)
        
        let hasA = ClipboardStore.shared.items.contains { $0.contentHash == hashA }
        check(hasA, "TEST 1: Screenshot A must appear in Pastry")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 2: Enable Pause Auto Screenshot Tracking -> Screenshot B -> NOT in Pastry
        // ────────────────────────────────────────────────────────────────
        SettingsManager.shared.isScreenshotTrackingPaused = true
        tickRunLoop(for: 0.1)
        
        let urlB = tmpDir.appendingPathComponent("Screenshot 2026-08-25 at 10.00.02.png")
        try? pngDataB.write(to: urlB)
        
        ScreenshotMonitor.shared.scanDirectorySync(directory: tmpDir)
        tickRunLoop(for: 0.5)
        
        let hasB_duringPause = ClipboardStore.shared.items.contains { $0.contentHash == hashB }
        check(!hasB_duringPause, "TEST 2: Screenshot B must NOT appear in Pastry while tracking is paused")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 3: Still Paused -> Screenshot C -> NOT in Pastry
        // ────────────────────────────────────────────────────────────────
        let urlC = tmpDir.appendingPathComponent("Screenshot 2026-08-25 at 10.00.03.png")
        try? pngDataC.write(to: urlC)
        
        ScreenshotMonitor.shared.scanDirectorySync(directory: tmpDir)
        tickRunLoop(for: 0.5)
        
        let hasC_duringPause = ClipboardStore.shared.items.contains { $0.contentHash == hashC }
        check(!hasC_duringPause, "TEST 3: Screenshot C must NOT appear in Pastry while tracking is paused")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 4: Resume Screenshot Tracking -> B and C STILL do NOT appear (No backlog rescan)
        // ────────────────────────────────────────────────────────────────
        SettingsManager.shared.isScreenshotTrackingPaused = false // triggers resumeTracking()
        tickRunLoop(for: 0.3)
        
        // Event check / sync scan should NOT import B or C
        ScreenshotMonitor.shared.scanDirectorySync(directory: tmpDir)
        tickRunLoop(for: 0.5)
        
        let hasB_afterResume = ClipboardStore.shared.items.contains { $0.contentHash == hashB }
        let hasC_afterResume = ClipboardStore.shared.items.contains { $0.contentHash == hashC }
        check(!hasB_afterResume, "TEST 4: Screenshot B must NEVER be imported after tracking resumes")
        check(!hasC_afterResume, "TEST 4: Screenshot C must NEVER be imported after tracking resumes")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 5: After Resuming -> Take Screenshot D -> Screenshot D Appears
        // ────────────────────────────────────────────────────────────────
        let urlD = tmpDir.appendingPathComponent("Screenshot 2026-08-25 at 10.00.04.png")
        try? pngDataD.write(to: urlD)
        
        ScreenshotMonitor.shared.scanDirectorySync(directory: tmpDir)
        tickRunLoop(for: 0.5)
        
        let hasD = ClipboardStore.shared.items.contains { $0.contentHash == hashD }
        check(hasD, "TEST 5: Screenshot D must appear in Pastry after tracking is resumed")
        check(!ClipboardStore.shared.items.contains { $0.contentHash == hashB }, "TEST 5: Screenshot B must STILL NOT be imported")
        check(!ClipboardStore.shared.items.contains { $0.contentHash == hashC }, "TEST 5: Screenshot C must STILL NOT be imported")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 6: Pause tracking -> Copy normal text "Hello world" -> Appears normally
        // ────────────────────────────────────────────────────────────────
        SettingsManager.shared.isScreenshotTrackingPaused = true
        tickRunLoop(for: 0.1)
        
        let textItem = ClipboardItem(type: .text, textContent: "Hello world", displayTitle: "Hello world")
        ClipboardStore.shared.add(item: textItem)
        tickRunLoop(for: 0.3)
        
        check(ClipboardStore.shared.items.first?.textContent == "Hello world", "TEST 6: Normal text copying must work while screenshot tracking is paused")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 7: Pause tracking -> Copy "25 * 4" -> Calculator works normally
        // ────────────────────────────────────────────────────────────────
        let calcExpr = "25 * 4"
        let calcResult = CalculatorEngine.shared.evaluate(calcExpr)
        check(calcResult == "100", "TEST 7: Calculator evaluation must work offline while screenshot tracking is paused")
        
        let calcItem = ClipboardItem(
            type: .text,
            textContent: calcExpr,
            displayTitle: calcExpr,
            calculationResult: calcResult
        )
        ClipboardStore.shared.add(item: calcItem)
        tickRunLoop(for: 0.3)
        
        check(ClipboardStore.shared.items.first?.calculationResult == "100", "TEST 7: Calculator item must appear in clipboard history while screenshot tracking is paused")
        
        print("✅ ScreenshotTests passed successfully!")
    }
}
