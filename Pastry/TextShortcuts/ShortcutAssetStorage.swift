import Foundation
import AppKit
import ImageIO

/// Manages physical storage, thumbnail generation, and deletion of Pastry-owned shortcut image assets.
/// All files are housed inside `~/Library/Application Support/Pastry/Shortcuts/`.
public class ShortcutAssetStorage {
    public static let shared = ShortcutAssetStorage()
    
    private let fileManager = FileManager.default
    
    private var baseDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Pastry", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    public var shortcutsDirectory: URL {
        let dir = baseDirectory.appendingPathComponent("Shortcuts", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    public var thumbnailsDirectory: URL {
        let dir = shortcutsDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private init() {}
    
    // MARK: - Asset Ingestion
    
    /// Copies an external image from `sourceURL` into Pastry's owned `Shortcuts/` directory.
    /// Returns the newly generated asset filename and the original filename.
    public func importImage(from sourceURL: URL) -> (assetFilename: String, originalName: String)? {
        guard fileManager.fileExists(atPath: sourceURL.path),
              let data = try? Data(contentsOf: sourceURL),
              isValidImage(data: data) else {
            return nil
        }
        
        let fileExtension = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension.lowercased()
        let assetFilename = "\(UUID().uuidString).\(fileExtension)"
        let originalName = sourceURL.lastPathComponent
        
        let destinationURL = shortcutsDirectory.appendingPathComponent(assetFilename)
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent(assetFilename)
        
        do {
            try data.write(to: destinationURL, options: .atomic)
            
            // Create and write thumbnail
            if let thumbData = createThumbnail(from: data) {
                try thumbData.write(to: thumbnailURL, options: .atomic)
            } else {
                try data.write(to: thumbnailURL, options: .atomic)
            }
            
            return (assetFilename, originalName)
        } catch {
            return nil
        }
    }
    
    /// Saves raw image data directly (useful for tests or programmatically added assets).
    public func saveImageData(_ data: Data, filenameExtension: String = "png", originalName: String = "image.png") -> (assetFilename: String, originalName: String)? {
        guard isValidImage(data: data) else { return nil }
        
        let assetFilename = "\(UUID().uuidString).\(filenameExtension)"
        let destinationURL = shortcutsDirectory.appendingPathComponent(assetFilename)
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent(assetFilename)
        
        do {
            try data.write(to: destinationURL, options: .atomic)
            if let thumbData = createThumbnail(from: data) {
                try thumbData.write(to: thumbnailURL, options: .atomic)
            }
            return (assetFilename, originalName)
        } catch {
            return nil
        }
    }
    
    // MARK: - Asset Retrieval
    
    public func loadImageData(assetFilename: String) -> Data? {
        let fileURL = shortcutsDirectory.appendingPathComponent(assetFilename)
        return try? Data(contentsOf: fileURL)
    }
    
    public func loadThumbnailImage(assetFilename: String) -> NSImage? {
        let thumbURL = thumbnailsDirectory.appendingPathComponent(assetFilename)
        if let thumbData = try? Data(contentsOf: thumbURL), let img = NSImage(data: thumbData) {
            return img
        }
        // Fallback to main asset if thumbnail missing
        if let mainData = loadImageData(assetFilename: assetFilename), let img = NSImage(data: mainData) {
            return img
        }
        return nil
    }
    
    // MARK: - Asset Cleanup
    
    /// Deletes the asset file and its thumbnail from disk.
    public func deleteAsset(assetFilename: String) {
        let fileURL = shortcutsDirectory.appendingPathComponent(assetFilename)
        let thumbURL = thumbnailsDirectory.appendingPathComponent(assetFilename)
        try? fileManager.removeItem(at: fileURL)
        try? fileManager.removeItem(at: thumbURL)
    }
    
    /// Deletes the asset file only if no remaining shortcut in `shortcuts` references it.
    public func deleteAssetIfUnreferenced(assetFilename: String, remainingShortcuts: [TextShortcut]) {
        let isReferenced = remainingShortcuts.contains { $0.imageAsset == assetFilename }
        if !isReferenced {
            deleteAsset(assetFilename: assetFilename)
        }
    }
    
    public func clearAll() {
        try? fileManager.removeItem(at: shortcutsDirectory)
    }
    
    // MARK: - Helpers
    
    private func isValidImage(data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return false
        }
        return CGImageSourceGetCount(source) > 0
    }
    
    private func createThumbnail(from data: Data) -> Data? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 120
        ]
        
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }
        
        let rep = NSBitmapImageRep(cgImage: thumbnail)
        return rep.representation(using: .png, properties: [:])
    }
}
