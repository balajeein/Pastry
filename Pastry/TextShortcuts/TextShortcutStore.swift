import Foundation
import Combine

/// Manages persistence, lookup, and mutation of text & image shortcuts.
/// 100% offline, local storage with zero network or telemetry.
public class TextShortcutStore: ObservableObject {
    public static let shared = TextShortcutStore()
    
    @Published public private(set) var shortcuts: [TextShortcut] = []
    
    private let queue = DispatchQueue(label: "com.balajee.Pastry.TextShortcutStore", qos: .utility)
    private let fileManager = FileManager.default
    
    private var storeFileURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Pastry", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("shortcuts.json")
    }
    
    private init() {
        load()
    }
    
    // MARK: - Fast In-Memory Lookup
    
    /// Finds a matching shortcut for a typed token using case-insensitive comparison.
    public func lookup(token: String) -> TextShortcut? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.lowercased()
        return shortcuts.first { $0.normalizedKey == normalized }
    }
    
    // MARK: - CRUD Operations
    
    @discardableResult
    public func add(shortcut: String, replacement: String) -> (success: Bool, error: String?) {
        return addTextShortcut(shortcut: shortcut, replacement: replacement)
    }
    
    @discardableResult
    public func addTextShortcut(shortcut: String, replacement: String) -> (success: Bool, error: String?) {
        if let validationError = TextShortcut.validate(
            shortcut: shortcut,
            type: .text,
            textContent: replacement,
            imageAsset: nil,
            existing: shortcuts
        ) {
            return (false, validationError)
        }
        
        let newShortcut = TextShortcut(shortcut: shortcut, type: .text, textContent: replacement)
        insertAndSave(newShortcut)
        return (true, nil)
    }
    
    @discardableResult
    public func addImageShortcut(shortcut: String, assetFilename: String, originalName: String) -> (success: Bool, error: String?) {
        if let validationError = TextShortcut.validate(
            shortcut: shortcut,
            type: .image,
            textContent: nil,
            imageAsset: assetFilename,
            existing: shortcuts
        ) {
            return (false, validationError)
        }
        
        let newShortcut = TextShortcut(
            shortcut: shortcut,
            type: .image,
            textContent: nil,
            imageAsset: assetFilename,
            imageName: originalName
        )
        insertAndSave(newShortcut)
        return (true, nil)
    }
    
    @discardableResult
    public func update(id: UUID, shortcut: String, replacement: String) -> (success: Bool, error: String?) {
        return updateTextShortcut(id: id, shortcut: shortcut, replacement: replacement)
    }
    
    @discardableResult
    public func updateTextShortcut(id: UUID, shortcut: String, replacement: String) -> (success: Bool, error: String?) {
        if let validationError = TextShortcut.validate(
            shortcut: shortcut,
            type: .text,
            textContent: replacement,
            imageAsset: nil,
            existing: shortcuts,
            editingId: id
        ) {
            return (false, validationError)
        }
        
        guard let index = shortcuts.firstIndex(where: { $0.id == id }) else {
            return (false, "Shortcut not found.")
        }
        
        let existing = shortcuts[index]
        let oldAsset = existing.imageAsset
        
        let updated = TextShortcut(
            id: existing.id,
            shortcut: shortcut,
            type: .text,
            textContent: replacement,
            imageAsset: nil,
            imageName: nil,
            createdAt: existing.createdAt
        )
        
        updateAndSave(at: index, item: updated)
        
        // Clean up old image asset if it was previously an image shortcut
        if let oldAsset = oldAsset {
            ShortcutAssetStorage.shared.deleteAssetIfUnreferenced(assetFilename: oldAsset, remainingShortcuts: shortcuts)
        }
        
        return (true, nil)
    }
    
    @discardableResult
    public func updateImageShortcut(id: UUID, shortcut: String, assetFilename: String, originalName: String) -> (success: Bool, error: String?) {
        if let validationError = TextShortcut.validate(
            shortcut: shortcut,
            type: .image,
            textContent: nil,
            imageAsset: assetFilename,
            existing: shortcuts,
            editingId: id
        ) {
            return (false, validationError)
        }
        
        guard let index = shortcuts.firstIndex(where: { $0.id == id }) else {
            return (false, "Shortcut not found.")
        }
        
        let existing = shortcuts[index]
        let oldAsset = existing.imageAsset
        
        let updated = TextShortcut(
            id: existing.id,
            shortcut: shortcut,
            type: .image,
            textContent: nil,
            imageAsset: assetFilename,
            imageName: originalName,
            createdAt: existing.createdAt
        )
        
        updateAndSave(at: index, item: updated)
        
        // Clean up old asset if it changed and is no longer referenced
        if let oldAsset = oldAsset, oldAsset != assetFilename {
            ShortcutAssetStorage.shared.deleteAssetIfUnreferenced(assetFilename: oldAsset, remainingShortcuts: shortcuts)
        }
        
        return (true, nil)
    }
    
    public func delete(id: UUID) {
        guard let index = shortcuts.firstIndex(where: { $0.id == id }) else { return }
        let item = shortcuts[index]
        let assetToDelete = item.imageAsset
        
        if Thread.isMainThread {
            shortcuts.remove(at: index)
            save()
        } else {
            DispatchQueue.main.async {
                self.shortcuts.remove(at: index)
                self.save()
            }
        }
        
        // Clean up asset if unreferenced
        if let asset = assetToDelete {
            ShortcutAssetStorage.shared.deleteAssetIfUnreferenced(assetFilename: asset, remainingShortcuts: shortcuts)
        }
    }
    
    public func delete(at indexSet: IndexSet) {
        let assetsToCheck = indexSet.compactMap { shortcuts[$0].imageAsset }
        
        if Thread.isMainThread {
            shortcuts.remove(atOffsets: indexSet)
            save()
        } else {
            DispatchQueue.main.async {
                self.shortcuts.remove(atOffsets: indexSet)
                self.save()
            }
        }
        
        for asset in assetsToCheck {
            ShortcutAssetStorage.shared.deleteAssetIfUnreferenced(assetFilename: asset, remainingShortcuts: shortcuts)
        }
    }
    
    private func insertAndSave(_ item: TextShortcut) {
        if Thread.isMainThread {
            shortcuts.insert(item, at: 0)
            save()
        } else {
            DispatchQueue.main.async {
                self.shortcuts.insert(item, at: 0)
                self.save()
            }
        }
    }
    
    private func updateAndSave(at index: Int, item: TextShortcut) {
        if Thread.isMainThread {
            shortcuts[index] = item
            save()
        } else {
            DispatchQueue.main.async {
                self.shortcuts[index] = item
                self.save()
            }
        }
    }
    
    // MARK: - Persistence
    
    public func save() {
        let itemsToSave = self.shortcuts
        queue.async {
            do {
                let data = try JSONEncoder().encode(itemsToSave)
                try data.write(to: self.storeFileURL, options: .atomic)
            } catch {
                // Ignore silently in production for privacy
            }
        }
    }
    
    public func load() {
        let url = storeFileURL
        guard fileManager.fileExists(atPath: url.path) else {
            seedInitialShortcuts()
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([TextShortcut].self, from: data)
            DispatchQueue.main.async {
                self.shortcuts = decoded.sorted(by: { $0.createdAt > $1.createdAt })
            }
        } catch {
            seedInitialShortcuts()
        }
    }
    
    private func seedInitialShortcuts() {
        let initial = [
            TextShortcut(shortcut: "myemail", type: .text, textContent: "balajee@gmail.com"),
            TextShortcut(shortcut: "myphone", type: .text, textContent: "+1 (555) 019-2834")
        ]
        DispatchQueue.main.async {
            self.shortcuts = initial
            self.save()
        }
    }
    
    // MARK: - Testing Helpers
    
    public func resetForTesting(shortcuts: [TextShortcut]) {
        self.shortcuts = shortcuts
    }
}
