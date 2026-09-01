import Foundation
import AppKit
import CoreGraphics
import Vision

/// Image-processing logic for stitching overlapping screenshot frames into one
/// tall (vertical) or wide (horizontal) image.
///
/// Uses Apple Vision `VNTranslationalImageRegistrationRequest` for sub-pixel
/// accurate frame alignment instead of brute-force pixel comparison.
public struct ImageStitcher {
    
    /// Scroll capture direction.
    public enum StitchDirection: String, Codable {
        case vertical
        case horizontal
    }
    
    /// The result of stitching multiple frames together.
    public struct StitchResult {
        public let image: CGImage
        public let pngData: Data
        public let frameCount: Int
        public let totalWidth: Int
        public let totalHeight: Int
    }
    
    /// Result of measuring the translation between two consecutive frames.
    public struct TranslationResult {
        /// Vertical displacement in pixels (positive = content moved up, i.e. scrolled down).
        public let dy: CGFloat
        /// Horizontal displacement in pixels.
        public let dx: CGFloat
        /// Vision confidence (0..1).
        public let confidence: Float
        /// Whether the measurement is considered reliable enough for stitching.
        public let isValid: Bool
    }
    
    // MARK: - Configuration
    
    /// Minimum fraction of the frame height that must overlap between consecutive frames.
    private static let minimumOverlapFraction: CGFloat = 0.15
    /// Maximum horizontal movement (pixels) tolerated between frames.
    private static let maximumHorizontalMovement: CGFloat = 5.0
    /// Dead zone — translations smaller than this are treated as "no movement".
    private static let movementDeadZone: CGFloat = 3.0
    /// Number of horizontal bands used for consensus validation.
    private static let comparisonBandCount = 5
    /// Minimum height (pixels) for a comparison band.
    private static let minimumBandHeight = 80
    /// Tolerance (pixels) for band consensus agreement.
    private static let agreementTolerance: CGFloat = 3.0
    /// Minimum Vision confidence for a valid full-frame fallback.
    private static let fullFrameConfidenceThreshold: Float = 0.5
    
    // MARK: - Public API: Batch Stitching (collects all frames, stitches at the end)
    
    /// Stitches an array of captured CGImages into one continuous image.
    /// Uses Vision-based alignment to detect the actual overlap between consecutive frames.
    ///
    /// - Parameters:
    ///   - frames: Array of CGImage frames captured during scrolling. Must contain at least 1 frame.
    ///   - direction: `.vertical` (default) or `.horizontal`.
    /// - Returns: A `StitchResult` with the final stitched image, or nil if stitching fails.
    public static func stitch(frames: [CGImage], direction: StitchDirection = .vertical) -> StitchResult? {
        guard !frames.isEmpty else { return nil }
        
        // Single frame — just return it directly
        if frames.count == 1 {
            guard let data = pngData(from: frames[0]) else { return nil }
            return StitchResult(
                image: frames[0],
                pngData: data,
                frameCount: 1,
                totalWidth: frames[0].width,
                totalHeight: frames[0].height
            )
        }
        
        switch direction {
        case .vertical:
            return stitchVertical(frames: frames)
        case .horizontal:
            return stitchHorizontal(frames: frames)
        }
    }
    
    // MARK: - Vision-Based Translation Detection
    
    /// Measures the translation between two consecutive frames using Apple Vision.
    ///
    /// Uses a multi-band consensus approach:
    /// 1. Splits frames into horizontal bands and measures translation on each band independently.
    /// 2. If enough bands agree (within tolerance), uses their consensus as the result.
    /// 3. Falls back to full-frame Vision registration if band consensus fails.
    ///
    /// - Parameters:
    ///   - previousFrame: The earlier frame (what was on screen before scrolling).
    ///   - currentFrame: The later frame (what is on screen after scrolling).
    /// - Returns: A `TranslationResult` with displacement and validity, or nil if Vision fails entirely.
    public static func detectTranslation(from previousFrame: CGImage, to currentFrame: CGImage) -> TranslationResult? {
        guard previousFrame.width == currentFrame.width,
              previousFrame.height == currentFrame.height else {
            print("[ImageStitcher] Frame dimensions mismatch: \(previousFrame.width)x\(previousFrame.height) vs \(currentFrame.width)x\(currentFrame.height)")
            return nil
        }
        
        let frameHeight = CGFloat(previousFrame.height)
        
        // Step 1: Multi-band consensus
        let bands = comparisonBands(for: previousFrame)
        var bandTranslations: [(dy: CGFloat, dx: CGFloat, confidence: Float)] = []
        
        for band in bands {
            guard let prevBand = previousFrame.cropping(to: band),
                  let currBand = currentFrame.cropping(to: band) else { continue }
            
            if let translation = visionTranslation(from: prevBand, to: currBand) {
                let maxVertical = frameHeight * (1 - minimumOverlapFraction)
                if abs(translation.dx) <= maximumHorizontalMovement && abs(translation.dy) <= maxVertical {
                    bandTranslations.append(translation)
                }
            }
        }
        
        // Try to find consensus among bands (3+ agreeing within tolerance)
        if let consensus = findConsensus(in: bandTranslations, minimumCount: 3) {
            return makeTranslationResult(dy: consensus.dy, dx: consensus.dx,
                                         confidence: consensus.confidence,
                                         frameHeight: frameHeight)
        }
        
        // Step 2: Full-frame Vision fallback
        if let fullFrame = visionTranslation(from: previousFrame, to: currentFrame) {
            let maxVertical = frameHeight * (1 - minimumOverlapFraction)
            if abs(fullFrame.dx) <= maximumHorizontalMovement && abs(fullFrame.dy) <= maxVertical
                && fullFrame.confidence >= fullFrameConfidenceThreshold {
                return makeTranslationResult(dy: fullFrame.dy, dx: fullFrame.dx,
                                             confidence: fullFrame.confidence,
                                             frameHeight: frameHeight)
            }
        }
        
        print("[ImageStitcher] Translation detection failed — no consensus and no valid full-frame result")
        return TranslationResult(dy: 0, dx: 0, confidence: 0, isValid: false)
    }
    
    // MARK: - Incremental Stitching
    
    /// Appends a new frame's unique content to an existing stitched image.
    ///
    /// Uses the measured displacement to extract only the newly revealed content from `newFrame`
    /// and draws it below the existing `baseImage`.
    ///
    /// - Parameters:
    ///   - baseImage: The accumulated stitched image so far.
    ///   - newFrame: The latest captured frame.
    ///   - displacementPixels: The measured vertical displacement in pixels (from `detectTranslation`).
    /// - Returns: The new stitched image with the appended content, or nil on failure.
    public static func appendFrame(baseImage: CGImage, newFrame: CGImage, displacementPixels: Int) -> CGImage? {
        let baseWidth = baseImage.width
        let baseHeight = baseImage.height
        let frameWidth = newFrame.width
        let frameHeight = newFrame.height
        
        guard baseWidth == frameWidth else {
            print("[ImageStitcher] Width mismatch in appendFrame: \(baseWidth) vs \(frameWidth)")
            return nil
        }
        
        // The displacement tells us how many new pixel rows are at the bottom of newFrame
        let newContentHeight = min(displacementPixels, frameHeight)
        guard newContentHeight > 0 else { return nil }
        
        let totalHeight = baseHeight + newContentHeight
        
        guard let context = CGContext(
            data: nil,
            width: baseWidth,
            height: totalHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // CGContext origin is bottom-left.
        // Draw the base image at the top (offset by newContentHeight from bottom).
        context.draw(baseImage, in: CGRect(x: 0, y: newContentHeight, width: baseWidth, height: baseHeight))
        
        // Crop the new content strip from the bottom of newFrame.
        // In CGImage coordinates (top-left origin), the bottom strip starts at (frameHeight - newContentHeight).
        let cropRect = CGRect(x: 0, y: frameHeight - newContentHeight, width: frameWidth, height: newContentHeight)
        guard let croppedStrip = newFrame.cropping(to: cropRect) else { return nil }
        
        // Draw the new strip at the bottom of the canvas (y=0 in CGContext).
        context.draw(croppedStrip, in: CGRect(x: 0, y: 0, width: baseWidth, height: newContentHeight))
        
        return context.makeImage()
    }
    
    // MARK: - Vertical Stitching (Batch — Vision-based)
    
    private static func stitchVertical(frames: [CGImage]) -> StitchResult? {
        // Compute Vision-based displacements for each consecutive pair
        var displacements: [Int] = []
        for i in 0..<(frames.count - 1) {
            if let result = detectTranslation(from: frames[i], to: frames[i + 1]), result.isValid {
                displacements.append(Int(result.dy.rounded()))
            } else {
                // If Vision fails, try legacy pixel overlap as a fallback
                let legacyOverlap = findOverlapLegacy(top: frames[i], bottom: frames[i + 1])
                let displacement = frames[i + 1].height - legacyOverlap
                displacements.append(max(0, displacement))
                print("[ImageStitcher] Vision failed for pair \(i)-\(i+1), using legacy overlap: \(legacyOverlap)")
            }
        }
        
        // Build stitched image incrementally
        var stitchedImage = frames[0]
        var frameCount = 1
        
        for i in 1..<frames.count {
            let displacement = displacements[i - 1]
            if displacement <= 0 {
                print("[ImageStitcher] Skipping duplicate frame \(i) (displacement: \(displacement))")
                continue
            }
            
            guard let newStitched = appendFrame(baseImage: stitchedImage, newFrame: frames[i],
                                                 displacementPixels: displacement) else {
                print("[ImageStitcher] Failed to append frame \(i)")
                continue
            }
            
            stitchedImage = newStitched
            frameCount += 1
        }
        
        guard let data = pngData(from: stitchedImage) else { return nil }
        
        return StitchResult(
            image: stitchedImage,
            pngData: data,
            frameCount: frameCount,
            totalWidth: stitchedImage.width,
            totalHeight: stitchedImage.height
        )
    }
    
    // MARK: - Horizontal Stitching (uses legacy pixel overlap for now)
    
    private static func stitchHorizontal(frames: [CGImage]) -> StitchResult? {
        var overlaps: [Int] = []
        for i in 0..<(frames.count - 1) {
            let overlap = findHorizontalOverlap(left: frames[i], right: frames[i + 1])
            overlaps.append(overlap)
        }
        
        var totalWidth = frames[0].width
        for i in 1..<frames.count {
            let newCols = frames[i].width - overlaps[i - 1]
            if newCols > 0 {
                totalWidth += newCols
            }
        }
        
        let height = frames[0].height
        
        guard let context = CGContext(
            data: nil,
            width: totalWidth,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // Draw first frame at the left
        context.draw(frames[0], in: CGRect(x: 0, y: 0, width: frames[0].width, height: height))
        var currentX = frames[0].width
        
        // Draw subsequent frames, skipping the overlapping left portion
        for i in 1..<frames.count {
            let overlap = overlaps[i - 1]
            let newCols = frames[i].width - overlap
            guard newCols > 0 else { continue }
            
            // In CGImage, x=0 is the LEFT. Skip left `overlap` columns, keep right `newCols` columns.
            let cropRect = CGRect(x: overlap, y: 0, width: newCols, height: height)
            guard let croppedImage = frames[i].cropping(to: cropRect) else { continue }
            
            // Draw immediately adjacent to the previous content
            context.draw(croppedImage, in: CGRect(x: currentX, y: 0, width: newCols, height: height))
            currentX += newCols
        }
        
        guard let stitchedImage = context.makeImage() else { return nil }
        guard let data = pngData(from: stitchedImage) else { return nil }
        
        return StitchResult(
            image: stitchedImage,
            pngData: data,
            frameCount: frames.count,
            totalWidth: totalWidth,
            totalHeight: height
        )
    }
    
    // MARK: - Vision Internals
    
    /// Runs VNTranslationalImageRegistrationRequest between two images.
    /// Returns the raw translation (dx, dy) in pixel coordinates and the confidence.
    private static func visionTranslation(from image1: CGImage, to image2: CGImage) -> (dy: CGFloat, dx: CGFloat, confidence: Float)? {
        let request = VNTranslationalImageRegistrationRequest(targetedCGImage: image2)
        let handler = VNImageRequestHandler(cgImage: image1, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("[ImageStitcher] Vision request failed: \(error)")
            return nil
        }
        
        guard let observation = request.results?.first as? VNImageTranslationAlignmentObservation else {
            return nil
        }
        
        let tx = observation.alignmentTransform.tx
        let ty = observation.alignmentTransform.ty
        
        // Vision reports ty as positive when the target needs to move UP to align with the reference.
        // For downward scrolling, the new frame's content is shifted UP relative to the previous frame,
        // so ty will be positive. We use abs(ty) as the displacement.
        return (dy: -ty, dx: -tx, confidence: observation.confidence)
    }
    
    /// Generates horizontal comparison bands spanning the full width of the image.
    private static func comparisonBands(for image: CGImage) -> [CGRect] {
        let imageHeight = image.height
        let imageWidth = image.width
        guard imageWidth > 0, imageHeight > 0 else { return [] }
        
        let bandHeight = min(imageHeight, max(minimumBandHeight, imageHeight / 3))
        let maxOriginY = max(0, imageHeight - bandHeight)
        
        let origins: [Int]
        if maxOriginY == 0 {
            origins = [0]
        } else {
            origins = (0..<comparisonBandCount).map { index in
                let denominator = max(1, comparisonBandCount - 1)
                return Int((CGFloat(maxOriginY) * CGFloat(index) / CGFloat(denominator)).rounded())
            }
        }
        
        // Deduplicate and sort
        return Array(Set(origins)).sorted().map { originY in
            CGRect(x: 0, y: originY, width: imageWidth, height: bandHeight)
        }
    }
    
    /// Finds the largest group of translations that agree within the tolerance.
    private static func findConsensus(in translations: [(dy: CGFloat, dx: CGFloat, confidence: Float)],
                                      minimumCount: Int) -> (dy: CGFloat, dx: CGFloat, confidence: Float)? {
        guard translations.count >= minimumCount else { return nil }
        
        var bestGroup: [(dy: CGFloat, dx: CGFloat, confidence: Float)] = []
        
        for t in translations {
            let group = translations.filter { abs($0.dy - t.dy) <= agreementTolerance }
            if group.count > bestGroup.count {
                bestGroup = group
            }
        }
        
        guard bestGroup.count >= minimumCount else { return nil }
        
        // Average the agreeing translations
        let count = CGFloat(bestGroup.count)
        let avgDy = bestGroup.reduce(CGFloat(0)) { $0 + $1.dy } / count
        let avgDx = bestGroup.reduce(CGFloat(0)) { $0 + $1.dx } / count
        let avgConf = bestGroup.reduce(Float(0)) { $0 + $1.confidence } / Float(bestGroup.count)
        
        return (dy: avgDy, dx: avgDx, confidence: avgConf)
    }
    
    /// Converts raw Vision measurements into a validated TranslationResult.
    private static func makeTranslationResult(dy: CGFloat, dx: CGFloat, confidence: Float,
                                              frameHeight: CGFloat) -> TranslationResult {
        let absDy = abs(dy)
        
        // Determine validity
        let maxVertical = frameHeight * (1 - minimumOverlapFraction)
        let withinDeadZone = absDy <= movementDeadZone
        let tooLarge = absDy > maxVertical
        let tooMuchHorizontal = abs(dx) > maximumHorizontalMovement
        
        let isValid = !withinDeadZone && !tooLarge && !tooMuchHorizontal
        
        return TranslationResult(
            dy: absDy,  // Always positive: represents how many new rows of content
            dx: dx,
            confidence: confidence,
            isValid: isValid
        )
    }
    
    // MARK: - Legacy Pixel-Based Overlap (Fallback)
    
    /// Legacy brute-force overlap detection. Used only as a fallback when Vision fails.
    /// Kept with reduced search range for safety.
    public static func findOverlapLegacy(top: CGImage, bottom: CGImage) -> Int {
        guard top.width == bottom.width else { return 0 }
        
        let width = top.width
        let topHeight = top.height
        let bottomHeight = bottom.height
        
        let minOverlap = max(8, min(topHeight, bottomHeight) / 20)
        let maxOverlap = min(topHeight, bottomHeight) * 95 / 100
        guard maxOverlap > minOverlap else { return 0 }
        
        guard let topData = pixelData(from: top),
              let bottomData = pixelData(from: bottom) else { return 0 }
        
        let topBytesPerRow = width * 4
        let bottomBytesPerRow = width * 4
        let bytesPerPixel = 4
        
        // Sample columns
        let numSampleColumns = min(width, max(16, width / 16))
        var sampleColumns: [Int] = []
        let colStep = max(1, width / numSampleColumns)
        var col = colStep / 2
        while col < width {
            sampleColumns.append(col)
            col += colStep
        }
        if sampleColumns.isEmpty { sampleColumns = [width / 2] }
        
        var bestOverlap = 0
        var bestScore = Double.infinity
        
        topData.withUnsafeBytes { topPtr in
            bottomData.withUnsafeBytes { bottomPtr in
                guard let topBase = topPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let bottomBase = bottomPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                
                let numCols = sampleColumns.count
                let channels = 3
                
                for h in minOverlap...maxOverlap {
                    var diffSum = 0
                    
                    for row in 0..<h {
                        let topRow = topHeight - h + row
                        let topRowOffset = topRow * topBytesPerRow
                        let bottomRowOffset = row * bottomBytesPerRow
                        
                        for cIdx in 0..<numCols {
                            let col = sampleColumns[cIdx]
                            let topPixelOffset = topRowOffset + col * bytesPerPixel
                            let bottomPixelOffset = bottomRowOffset + col * bytesPerPixel
                            
                            for c in 0..<channels {
                                let topVal = Int(topBase[topPixelOffset + c])
                                let bottomVal = Int(bottomBase[bottomPixelOffset + c])
                                diffSum += abs(topVal - bottomVal)
                            }
                        }
                    }
                    
                    let totalSamples = h * numCols * channels
                    let score = Double(diffSum) / Double(totalSamples)
                    
                    if score < bestScore {
                        bestScore = score
                        bestOverlap = h
                    }
                }
            }
        }
        
        if bestScore > 25.0 {
            return 0
        }
        
        return bestOverlap
    }
    
    // Keep the old public name for backward compatibility with tests
    /// Finds the vertical overlap between the bottom of `top` image and the top of `bottom` image.
    /// Now uses Vision-based detection with legacy fallback.
    public static func findOverlap(top: CGImage, bottom: CGImage) -> Int {
        // Try Vision first
        if let result = detectTranslation(from: top, to: bottom), result.isValid {
            let overlap = top.height - Int(result.dy.rounded())
            return max(0, overlap)
        }
        // Fallback to legacy
        return findOverlapLegacy(top: top, bottom: bottom)
    }
    
    // MARK: - Horizontal Overlap Detection (legacy pixel-based)
    
    /// Finds the horizontal overlap between the right side of `left` image and the left side of `right` image.
    /// Uses normalized mean absolute difference per sampled pixel to ensure scale-independent accuracy.
    public static func findHorizontalOverlap(left: CGImage, right: CGImage) -> Int {
        guard left.height == right.height else { return 0 }
        
        let height = left.height
        let leftWidth = left.width
        let rightWidth = right.width
        
        let minOverlap = max(8, min(leftWidth, rightWidth) / 20)
        let maxOverlap = min(leftWidth, rightWidth) * 95 / 100
        guard maxOverlap > minOverlap else { return 0 }
        
        guard let leftData = pixelData(from: left),
              let rightData = pixelData(from: right) else { return 0 }
        
        let leftBytesPerRow = leftWidth * 4
        let rightBytesPerRow = rightWidth * 4
        let bytesPerPixel = 4
        
        // Sample dense rows (up to 48 rows across the height)
        let numSampleRows = min(height, max(16, height / 16))
        var sampleRows: [Int] = []
        let rowStep = max(1, height / numSampleRows)
        var r = rowStep / 2
        while r < height {
            sampleRows.append(r)
            r += rowStep
        }
        if sampleRows.isEmpty { sampleRows = [height / 2] }
        
        var bestOverlap = 0
        var bestScore = Double.infinity
        
        leftData.withUnsafeBytes { leftPtr in
            rightData.withUnsafeBytes { rightPtr in
                guard let leftBase = leftPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let rightBase = rightPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                
                let numRows = sampleRows.count
                let channels = 3
                
                for w in minOverlap...maxOverlap {
                    var diffSum = 0
                    
                    for col in 0..<w {
                        let leftCol = leftWidth - w + col
                        let rightCol = col
                        
                        for rIdx in 0..<numRows {
                            let row = sampleRows[rIdx]
                            let leftPixelOffset = row * leftBytesPerRow + leftCol * bytesPerPixel
                            let rightPixelOffset = row * rightBytesPerRow + rightCol * bytesPerPixel
                            
                            for c in 0..<channels {
                                let leftVal = Int(leftBase[leftPixelOffset + c])
                                let rightVal = Int(rightBase[rightPixelOffset + c])
                                diffSum += abs(leftVal - rightVal)
                            }
                        }
                    }
                    
                    let totalSamples = w * numRows * channels
                    let score = Double(diffSum) / Double(totalSamples)
                    
                    if score < bestScore {
                        bestScore = score
                        bestOverlap = w
                    }
                }
            }
        }
        
        if bestScore > 25.0 {
            return 0
        }
        
        return bestOverlap
    }
    
    // MARK: - Helpers
    
    /// Extracts raw pixel data from a CGImage with top-left origin.
    private static func pixelData(from image: CGImage) -> Data? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // Flip vertically so row 0 in memory = top row of the image
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let dataPtr = context.data else { return nil }
        return Data(bytes: dataPtr, count: totalBytes)
    }
    
    /// Converts a CGImage to PNG Data.
    public static func pngData(from image: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .png, properties: [:])
    }
    
    /// Compares two CGImages by pixel data equality.
    public static func areFramesIdentical(_ a: CGImage, _ b: CGImage) -> Bool {
        guard a.width == b.width && a.height == b.height else { return false }
        guard let aData = pixelData(from: a),
              let bData = pixelData(from: b) else { return false }
        return aData == bData
    }
}
