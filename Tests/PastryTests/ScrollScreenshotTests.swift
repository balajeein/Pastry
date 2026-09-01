import Foundation
import AppKit

public struct ScrollScreenshotTests {
    public static func runAll() {
        print("🧪 Running ScrollScreenshotTests...")
        
        func check(_ condition: Bool, _ msg: String, line: Int = #line) {
            if !condition {
                print("❌ FAIL [line \(line)]: \(msg)")
                exit(1)
            }
        }
        
        // Helper to create a solid-color CGImage using CGContext
        func makeImage(width: Int, height: Int, color: NSColor) -> CGImage {
            guard let context = CGContext(
                data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { fatalError("Failed to create CGContext") }
            
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            return context.makeImage()!
        }
        
        // Helper to create an image with horizontal colored bands (for vertical scrolling test)
        func makeBandedImage(width: Int, bandHeight: Int, bandColors: [NSColor]) -> CGImage {
            let height = bandHeight * bandColors.count
            guard let context = CGContext(
                data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { fatalError("Failed to create CGContext") }
            
            for (i, color) in bandColors.enumerated() {
                context.setFillColor(color.cgColor)
                context.fill(CGRect(x: 0, y: i * bandHeight, width: width, height: bandHeight))
            }
            return context.makeImage()!
        }
        
        // ────────────────────────────────────────────────────────────────
        // TEST 1: Single frame stitch returns the frame unchanged
        // ────────────────────────────────────────────────────────────────
        let singleFrame = makeImage(width: 100, height: 80, color: .red)
        let singleResult = ImageStitcher.stitch(frames: [singleFrame], direction: .vertical)
        check(singleResult != nil, "TEST 1: Single frame stitch must succeed")
        check(singleResult!.frameCount == 1, "TEST 1: Frame count must be 1")
        check(singleResult!.totalHeight == singleFrame.height, "TEST 1: Total height must equal frame pixel height")
        check(!singleResult!.pngData.isEmpty, "TEST 1: PNG data must not be empty")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 2: Empty frames returns nil
        // ────────────────────────────────────────────────────────────────
        let emptyResult = ImageStitcher.stitch(frames: [], direction: .vertical)
        check(emptyResult == nil, "TEST 2: Empty frames must return nil")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 3: Two identical banded frames — stitcher handles gracefully
        // ────────────────────────────────────────────────────────────────
        let identFrame1 = makeBandedImage(width: 100, bandHeight: 20, bandColors: [.red, .green, .blue, .cyan, .magenta])
        let identFrame2 = makeBandedImage(width: 100, bandHeight: 20, bandColors: [.red, .green, .blue, .cyan, .magenta])
        
        let identResult = ImageStitcher.stitch(frames: [identFrame1, identFrame2], direction: .vertical)
        check(identResult != nil, "TEST 3: Identical banded frames stitch must succeed")
        check(identResult!.frameCount >= 1, "TEST 3: Frame count must be at least 1")
        check(identResult!.totalHeight > 0, "TEST 3: Total height must be positive")
        check(!identResult!.pngData.isEmpty, "TEST 3: PNG data must not be empty")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 4: areFramesIdentical detects identical frames
        // ────────────────────────────────────────────────────────────────
        let frameA = makeImage(width: 50, height: 50, color: .green)
        let frameB = makeImage(width: 50, height: 50, color: .green)
        let frameC = makeImage(width: 50, height: 50, color: .yellow)
        
        check(ImageStitcher.areFramesIdentical(frameA, frameB), "TEST 4: Same-color frames must be identical")
        check(!ImageStitcher.areFramesIdentical(frameA, frameC), "TEST 4: Different-color frames must not be identical")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 5: Legacy overlap detection with overlapping bands (Vertical)
        // ────────────────────────────────────────────────────────────────
        let bandH = 40
        let frame1 = makeBandedImage(width: 200, bandHeight: bandH, bandColors: [.red, .green, .blue])
        let frame2 = makeBandedImage(width: 200, bandHeight: bandH, bandColors: [.green, .blue, .yellow])
        
        let overlap = ImageStitcher.findOverlapLegacy(top: frame1, bottom: frame2)
        let scaledBandH = frame1.height / 3
        check(overlap >= scaledBandH && overlap <= scaledBandH * 3, "TEST 5: Legacy overlap should be around \(scaledBandH * 2) pixels (got \(overlap))")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 6: Vertical Stitch with overlapping bands produces correct height
        // ────────────────────────────────────────────────────────────────
        let bandResult = ImageStitcher.stitch(frames: [frame1, frame2], direction: .vertical)
        check(bandResult != nil, "TEST 6: Band stitch must succeed")
        check(bandResult!.totalHeight > 0, "TEST 6: Total height must be positive")
        check(!bandResult!.pngData.isEmpty, "TEST 6: PNG data must not be empty")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 7: Different-dimension frames handled gracefully
        // ────────────────────────────────────────────────────────────────
        let wideFrame = makeImage(width: 200, height: 100, color: .orange)
        let narrowFrame = makeImage(width: 150, height: 100, color: .orange)
        let mismatchOverlap = ImageStitcher.findOverlapLegacy(top: wideFrame, bottom: narrowFrame)
        check(mismatchOverlap == 0, "TEST 7: Different-width frames should return 0 vertical overlap")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 8: appendFrame produces correct dimensions
        // ────────────────────────────────────────────────────────────────
        let baseImg = makeImage(width: 200, height: 300, color: .blue)
        let newImg = makeImage(width: 200, height: 300, color: .red)
        let displacement = 100
        
        let appendResult = ImageStitcher.appendFrame(baseImage: baseImg, newFrame: newImg,
                                                      displacementPixels: displacement)
        check(appendResult != nil, "TEST 8: appendFrame must succeed")
        check(appendResult!.width == 200, "TEST 8: Width must match (got \(appendResult!.width))")
        check(appendResult!.height == 400, "TEST 8: Height must be 300 + 100 = 400 (got \(appendResult!.height))")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 9: appendFrame with mismatched width returns nil
        // ────────────────────────────────────────────────────────────────
        let mismatchNewFrame = makeImage(width: 150, height: 300, color: .red)
        let mismatchAppend = ImageStitcher.appendFrame(baseImage: baseImg, newFrame: mismatchNewFrame,
                                                        displacementPixels: 100)
        check(mismatchAppend == nil, "TEST 9: appendFrame with different width must return nil")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 10: appendFrame with zero displacement returns nil
        // ────────────────────────────────────────────────────────────────
        let zeroAppend = ImageStitcher.appendFrame(baseImage: baseImg, newFrame: newImg,
                                                    displacementPixels: 0)
        check(zeroAppend == nil, "TEST 10: appendFrame with zero displacement must return nil")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 11: Multi-frame incremental stitch accumulates height correctly
        // ────────────────────────────────────────────────────────────────
        var accumulated = makeImage(width: 100, height: 200, color: .blue)
        let increments = [50, 75, 30, 60]
        var expectedTotal = 200
        
        for (i, disp) in increments.enumerated() {
            let nextFrame = makeImage(width: 100, height: 200, color: NSColor(
                red: CGFloat(i) / 4.0, green: 0.5, blue: 0.5, alpha: 1.0
            ))
            guard let result = ImageStitcher.appendFrame(baseImage: accumulated, newFrame: nextFrame,
                                                          displacementPixels: disp) else {
                check(false, "TEST 11: appendFrame iteration \(i) must succeed")
                return
            }
            expectedTotal += disp
            accumulated = result
        }
        
        check(accumulated.width == 100, "TEST 11: Final width must be 100 (got \(accumulated.width))")
        check(accumulated.height == expectedTotal, "TEST 11: Final height must be \(expectedTotal) (got \(accumulated.height))")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 12: detectTranslation returns nil for mismatched dimensions
        // ────────────────────────────────────────────────────────────────
        let transResult = ImageStitcher.detectTranslation(from: wideFrame, to: narrowFrame)
        check(transResult == nil, "TEST 12: detectTranslation with different dimensions must return nil")
        
        // ────────────────────────────────────────────────────────────────
        // TEST 13: pngData conversion works
        // ────────────────────────────────────────────────────────────────
        let pngResult = ImageStitcher.pngData(from: singleFrame)
        check(pngResult != nil, "TEST 13: pngData must succeed")
        check(!pngResult!.isEmpty, "TEST 13: pngData must not be empty")
        
        print("✅ ScrollScreenshotTests passed successfully!")
    }
}
