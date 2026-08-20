import Foundation

public class ClipboardStore: ObservableObject {
    public static let shared = ClipboardStore()
    
    @Published public private(set) var items: [ClipboardItem] = []
    
    private let queue = DispatchQueue(label: "com.balajee.Pastry.ClipboardStore", qos: .utility)
    private let fileManager = FileManager.default
    
    private var historyFileURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Pastry", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }
    
    private init() {
        loadHistory()
    }
    
    public func add(item: ClipboardItem) {
        DispatchQueue.main.async {
            self.addItemInternal(item)
        }
    }
    
    public func forceAddForTest(item: ClipboardItem) {
        // Direct addition for testing purposes (ignores async delays if required)
        addItemInternal(item)
    }
    
    private func addItemInternal(_ newItem: ClipboardItem) {
        // 1. Deduplication
        if let existingIndex = items.firstIndex(where: { $0 == newItem }) {
            let existingItem = items[existingIndex]
            items.remove(at: existingIndex)
            
            // Re-create with new timestamp but preserving original content and paths
            let updatedItem = ClipboardItem(
                id: existingItem.id,
                type: existingItem.type,
                timestamp: Date(),
                textContent: existingItem.textContent,
                storagePath: existingItem.storagePath,
                displayTitle: existingItem.displayTitle,
                subtitle: existingItem.subtitle,
                representations: existingItem.representations
            )
            items.insert(updatedItem, at: 0)
        } else {
            items.insert(newItem, at: 0)
            enforceLimits()
        }
        
        saveHistory()
    }
    
    public func enforceLimits() {
        let textLimit = UserDefaults.standard.integer(forKey: "textHistoryLimit") == 0 ? 20 : UserDefaults.standard.integer(forKey: "textHistoryLimit")
        let imageLimit = UserDefaults.standard.integer(forKey: "imageHistoryLimit") == 0 ? 10 : UserDefaults.standard.integer(forKey: "imageHistoryLimit")
        let otherLimit = UserDefaults.standard.integer(forKey: "otherHistoryLimit") == 0 ? 10 : UserDefaults.standard.integer(forKey: "otherHistoryLimit")
        
        var textCount = 0
        var imageCount = 0
        var otherCount = 0
        
        var itemsToRemove: [ClipboardItem] = []
        var filteredItems: [ClipboardItem] = []
        
        for item in items {
            switch item.type {
            case .text, .url:
                if textCount < textLimit {
                    textCount += 1
                    filteredItems.append(item)
                } else {
                    itemsToRemove.append(item)
                }
            case .image:
                if imageCount < imageLimit {
                    imageCount += 1
                    filteredItems.append(item)
                } else {
                    itemsToRemove.append(item)
                }
            case .file, .other:
                if otherCount < otherLimit {
                    otherCount += 1
                    filteredItems.append(item)
                } else {
                    itemsToRemove.append(item)
                }
            }
        }
        
        self.items = filteredItems
        
        // Clean up storage for removed items in background
        queue.async {
            for item in itemsToRemove {
                if let path = item.storagePath {
                    ImageStorage.shared.deleteImage(path: path)
                }
            }
        }
    }
    
    public func clearHistory() {
        DispatchQueue.main.async {
            self.items.removeAll()
            self.saveHistory()
            self.queue.async {
                ImageStorage.shared.clearAll()
            }
        }
    }
    
    public func saveHistory() {
        let itemsToSave = self.items
        queue.async {
            do {
                let data = try JSONEncoder().encode(itemsToSave)
                try data.write(to: self.historyFileURL)
            } catch {
                // Safe logging, no clipboard contents
            }
        }
    }
    
    public func loadHistory() {
        let url = historyFileURL
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([ClipboardItem].self, from: data)
            DispatchQueue.main.async {
                self.items = decoded.sorted(by: { $0.timestamp > $1.timestamp })
            }
        } catch {
            // Corrupt file, will be overwritten next save
        }
    }
}
