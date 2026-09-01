import Foundation
import Combine

/// Manages persistence, lookup, and mutation of text shortcuts.
/// 100% offline, local storage, with zero network or telemetry.
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
    /// Returns the configured TextShortcut if found.
    public func lookup(token: String) -> TextShortcut? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.lowercased()
        return shortcuts.first { $0.normalizedKey == normalized }
    }
    
    // MARK: - CRUD Operations
    
    @discardableResult
    public func add(shortcut: String, replacement: String) -> (success: Bool, error: String?) {
        if let validationError = TextShortcut.validate(shortcut: shortcut, replacement: replacement, existing: shortcuts) {
            return (false, validationError)
        }
        
        let newShortcut = TextShortcut(shortcut: shortcut, replacement: replacement)
        if Thread.isMainThread {
            shortcuts.insert(newShortcut, at: 0)
            save()
        } else {
            DispatchQueue.main.async {
                self.shortcuts.insert(newShortcut, at: 0)
                self.save()
            }
        }
        return (true, nil)
    }
    
    @discardableResult
    public func update(id: UUID, shortcut: String, replacement: String) -> (success: Bool, error: String?) {
        if let validationError = TextShortcut.validate(shortcut: shortcut, replacement: replacement, existing: shortcuts, editingId: id) {
            return (false, validationError)
        }
        
        guard let index = shortcuts.firstIndex(where: { $0.id == id }) else {
            return (false, "Shortcut not found.")
        }
        
        let existing = shortcuts[index]
        let updated = TextShortcut(id: existing.id, shortcut: shortcut, replacement: replacement, createdAt: existing.createdAt)
        
        if Thread.isMainThread {
            shortcuts[index] = updated
            save()
        } else {
            DispatchQueue.main.async {
                self.shortcuts[index] = updated
                self.save()
            }
        }
        return (true, nil)
    }
    
    public func delete(id: UUID) {
        if Thread.isMainThread {
            shortcuts.removeAll { $0.id == id }
            save()
        } else {
            DispatchQueue.main.async {
                self.shortcuts.removeAll { $0.id == id }
                self.save()
            }
        }
    }
    
    public func delete(at indexSet: IndexSet) {
        if Thread.isMainThread {
            shortcuts.remove(atOffsets: indexSet)
            save()
        } else {
            DispatchQueue.main.async {
                self.shortcuts.remove(atOffsets: indexSet)
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
                // Ignore failure silently in production for privacy
            }
        }
    }
    
    public func load() {
        let url = storeFileURL
        guard fileManager.fileExists(atPath: url.path) else {
            // Seed initial sample shortcut on first run
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
        // Provide clean initial examples if no shortcuts exist
        let initial = [
            TextShortcut(shortcut: "myemail", replacement: "balajee@gmail.com"),
            TextShortcut(shortcut: "myphone", replacement: "+1 (555) 019-2834")
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
