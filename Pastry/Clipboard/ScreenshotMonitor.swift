import Foundation
import AppKit
import CryptoKit

public class ScreenshotMonitor {
    public static let shared = ScreenshotMonitor()
    
    private var source: DispatchSourceFileSystemObject?
    private var dirFileDescriptor: Int32 = -1
    private var processedFileURLs: Set<URL> = []
    private var processedHashes: Set<String> = []
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
    
    public func resetTrackingForTest() {
        queue.sync {
            self.processedFileURLs.removeAll()
            self.processedHashes.removeAll()
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
        
        // Initial scan of recent screenshots (within last 3 seconds)
        handleDirectoryChange(directory: screenshotDir, timeWindow: 3.0)
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
    
    public func scanDirectoryNow(directory: URL? = nil, timeWindow: TimeInterval = 10.0) {
        let dir = directory ?? ScreenshotMonitor.getScreenshotDirectory()
        queue.async {
            self.handleDirectoryChange(directory: dir, timeWindow: timeWindow)
        }
    }
    
    public func scanDirectorySync(directory: URL? = nil, timeWindow: TimeInterval = 10.0) {
        let dir = directory ?? ScreenshotMonitor.getScreenshotDirectory()
        queue.sync {
            self.handleDirectoryChange(directory: dir, timeWindow: timeWindow)
        }
    }
    
    private func handleDirectoryChange(directory: URL, timeWindow: TimeInterval = 120.0) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        let now = Date()
        
        for fileURL in files {
            let ext = fileURL.pathExtension.lowercased()
            guard ext == "png" || ext == "jpg" || ext == "jpeg" else { continue }
            
            let fileName = fileURL.lastPathComponent
            let isScreenshotName = fileName.hasPrefix("Screenshot") ||
                                   fileName.hasPrefix("Screen Shot") ||
                                   fileName.hasPrefix("ScreenShot") ||
                                   fileName.contains("Screenshot") ||
                                   fileName.contains("Screen Shot")
            
            guard isScreenshotName else { continue }
            
            let values = try? fileURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey, .fileSizeKey])
            let creationDate = values?.creationDate ?? values?.contentModificationDate ?? Date()
            let fileSize = values?.fileSize ?? (try? Data(contentsOf: fileURL).count) ?? 0
            guard fileSize > 0 else { continue }
            
            if abs(now.timeIntervalSince(creationDate)) <= timeWindow {
                processScreenshotFile(at: fileURL)
            }
        }
    }
    
    private func processScreenshotFile(at fileURL: URL) {
        guard !processedFileURLs.contains(fileURL) else { return }
        
        var data: Data? = nil
        for _ in 0..<5 {
            if let d = try? Data(contentsOf: fileURL), d.count > 0 {
                data = d
                break
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        guard let imageData = data else { return }
        
        let digest = SHA256.hash(data: imageData)
        let hashString = digest.map { String(format: "%02x", $0) }.joined()
        
        guard !processedHashes.contains(hashString) else { return }
        
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
