import Foundation
import AppKit
import CryptoKit

public class ScreenshotMonitor {
    public static let shared = ScreenshotMonitor()
    
    private var source: DispatchSourceFileSystemObject?
    private var dirFileDescriptor: Int32 = -1
    private var processedFileURLs: Set<URL> = []
    private var processedHashes: Set<String> = []
    private var monitoringStartTime: Date = Date()
    private let queue = DispatchQueue(label: "com.balajee.Pastry.ScreenshotMonitor", qos: .utility)
    
    private init() {}
    
    public func startMonitoring() {
        queue.async {
            self.stopMonitoringInternal()
            self.setupMonitoring()
        }
    }
    
    public func stopMonitoring() {
        queue.async {
            self.stopMonitoringInternal()
        }
    }
    
    public func resumeTracking() {
        queue.async {
            self.updateBaselineToNowInternal()
        }
    }
    
    public func resetTrackingForTest() {
        queue.sync {
            self.processedFileURLs.removeAll()
            self.processedHashes.removeAll()
            self.monitoringStartTime = Date.distantPast
        }
    }
    
    private func stopMonitoringInternal() {
        if let source = source {
            source.cancel()
            self.source = nil
        }
        if dirFileDescriptor != -1 {
            close(dirFileDescriptor)
            dirFileDescriptor = -1
        }
    }
    
    private func setupMonitoring() {
        let screenshotDir = ScreenshotMonitor.getScreenshotDirectory()
        let fm = FileManager.default
        
        guard fm.fileExists(atPath: screenshotDir.path) else { return }
        
        let fd = open(screenshotDir.path, O_EVTONLY)
        guard fd != -1 else { return }
        self.dirFileDescriptor = fd
        
        updateBaselineToNowInternal()
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: queue
        )
        
        source.setEventHandler { [weak self] in
            self?.handleDirectoryChange(directory: screenshotDir)
        }
        
        source.setCancelHandler {
            close(fd)
        }
        
        self.source = source
        source.resume()
    }
    
    public func updateBaselineToNow() {
        queue.async {
            self.updateBaselineToNowInternal()
        }
    }
    
    private func updateBaselineToNowInternal() {
        monitoringStartTime = Date()
        let screenshotDir = ScreenshotMonitor.getScreenshotDirectory()
        let fm = FileManager.default
        if let existingFiles = try? fm.contentsOfDirectory(at: screenshotDir, includingPropertiesForKeys: nil, options: []) {
            for file in existingFiles {
                processedFileURLs.insert(file)
            }
        }
    }
    
    /// Resolves active macOS screenshot destination directory (respecting `defaults read com.apple.screencapture location`)
    public static func getScreenshotDirectory() -> URL {
        if let path = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"),
           !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let expanded = (path as NSString).expandingTildeInPath
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue {
                return URL(fileURLWithPath: expanded)
            }
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    }
    
    public func scanDirectoryNow(directory: URL? = nil) {
        let dir = directory ?? ScreenshotMonitor.getScreenshotDirectory()
        queue.async {
            self.handleDirectoryChange(directory: dir)
        }
    }
    
    public func scanDirectorySync(directory: URL? = nil) {
        let dir = directory ?? ScreenshotMonitor.getScreenshotDirectory()
        queue.sync {
            self.handleDirectoryChange(directory: dir)
        }
    }
    
    private func handleDirectoryChange(directory: URL) {
        let isPaused = UserDefaults.standard.bool(forKey: "isHistoryPaused") || UserDefaults.standard.bool(forKey: "isScreenshotTrackingPaused")
        
        let fm = FileManager.default
        // Do NOT use [.skipsHiddenFiles] so hidden screenshot temp files (.Screenshot...) are detected immediately while floating preview is visible!
        guard let files = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey],
            options: []
        ) else { return }
        
        for fileURL in files {
            let rawName = fileURL.lastPathComponent
            var cleanName = rawName
            while cleanName.hasPrefix(".") {
                cleanName.removeFirst()
            }
            if let hyphenIdx = cleanName.firstIndex(of: "-") {
                cleanName = String(cleanName[..<hyphenIdx])
            }
            
            let isScreenshotName = cleanName.hasPrefix("Screenshot") ||
                                   cleanName.hasPrefix("Screen Shot") ||
                                   cleanName.hasPrefix("ScreenShot") ||
                                   cleanName.contains("Screenshot") ||
                                   cleanName.contains("Screen Shot")
            
            guard isScreenshotName else { continue }
            
            let ext = fileURL.pathExtension.lowercased()
            let isImageExt = ext == "png" || ext == "jpg" || ext == "jpeg" || rawName.contains(".png") || rawName.contains(".jpg")
            guard isImageExt else { continue }
            
            // If paused: mark all existing/incoming screenshot files as seen/processed so they are permanently ignored!
            if isPaused {
                processedFileURLs.insert(fileURL)
                continue
            }
            
            let values = try? fileURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey])
            let creationDate = values?.creationDate ?? values?.contentModificationDate ?? Date()
            
            // Strictly enforce creationDate >= monitoringStartTime (minus 0.5s clock tolerance)
            guard creationDate >= monitoringStartTime.addingTimeInterval(-0.5) else {
                processedFileURLs.insert(fileURL)
                continue
            }
            
            processScreenshotFile(at: fileURL)
        }
    }
    
    private func processScreenshotFile(at fileURL: URL) {
        guard !processedFileURLs.contains(fileURL) else { return }
        
        var data: Data? = nil
        for _ in 0..<5 {
            if let d = try? Data(contentsOf: fileURL), d.count > 100 {
                if let source = CGImageSourceCreateWithData(d as CFData, nil), CGImageSourceGetCount(source) > 0 {
                    data = d
                    break
                }
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        
        guard let imageData = data else { return }
        
        let digest = SHA256.hash(data: imageData)
        let hashString = digest.map { String(format: "%02x", $0) }.joined()
        
        guard !processedHashes.contains(hashString) else {
            processedFileURLs.insert(fileURL)
            return
        }
        
        processedFileURLs.insert(fileURL)
        processedHashes.insert(hashString)
        
        let id = UUID()
        guard let paths = ImageStorage.shared.saveImage(data: imageData, id: id) else { return }
        
        let sizeDesc = ImageStorage.shared.getImageSizeDescription(path: paths.imagePath) ?? "Screenshot"
        let item = ClipboardItem(
            id: id,
            type: .image,
            timestamp: Date(),
            storagePath: paths.imagePath,
            displayTitle: "Screenshot",
            subtitle: sizeDesc,
            contentHash: hashString
        )
        
        ClipboardStore.shared.add(item: item)
    }
}
