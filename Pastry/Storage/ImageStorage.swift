import Foundation
import AppKit
import ImageIO

public class ImageStorage {
    public static let shared = ImageStorage()
    
    private let fileManager = FileManager.default
    
    private var baseDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Pastry", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    public var imagesDirectory: URL {
        let dir = baseDirectory.appendingPathComponent("Images", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    public var thumbnailsDirectory: URL {
        let dir = baseDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    public func saveImage(data: Data, id: UUID) -> (imagePath: String, thumbnailPath: String)? {
        let filename = "\(id.uuidString).png"
        let imageURL = imagesDirectory.appendingPathComponent(filename)
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent(filename)
        
        do {
            // Save full image
            try data.write(to: imageURL)
            
            // Create and save thumbnail
            if let thumbnailData = createThumbnail(from: data) {
                try thumbnailData.write(to: thumbnailURL)
            } else {
                // Fallback: copy original if thumbnail creation fails
                try data.write(to: thumbnailURL)
            }
            
            return (filename, filename)
        } catch {
            // Do not print clipboard contents, just log generic error
            return nil
        }
    }
    
    public func loadImage(path: String) -> Data? {
        let imageURL = imagesDirectory.appendingPathComponent(path)
        return try? Data(contentsOf: imageURL)
    }
    
    public func loadThumbnail(path: String) -> Data? {
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent(path)
        return try? Data(contentsOf: thumbnailURL)
    }
    
    public func deleteImage(path: String) {
        let imageURL = imagesDirectory.appendingPathComponent(path)
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent(path)
        try? fileManager.removeItem(at: imageURL)
        try? fileManager.removeItem(at: thumbnailURL)
    }
    
    public func clearAll() {
        try? fileManager.removeItem(at: imagesDirectory)
        try? fileManager.removeItem(at: thumbnailsDirectory)
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
public extension ImageStorage {
    // Utility to get image file sizes for metadata display
    func getImageSizeDescription(path: String) -> String? {
        let imageURL = imagesDirectory.appendingPathComponent(path)
        guard let attributes = try? fileManager.attributesOfItem(atPath: imageURL.path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
