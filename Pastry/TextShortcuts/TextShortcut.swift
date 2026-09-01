import Foundation

/// Defines whether the shortcut expands into plain text or an image.
public enum ShortcutType: String, Codable, CaseIterable {
    case text
    case image
}

/// Represents a user-defined shortcut that expands into either Text or an Image.
public struct TextShortcut: Identifiable, Codable, Equatable {
    public let id: UUID
    public var shortcut: String
    public var type: ShortcutType
    public var textContent: String?
    public var imageAsset: String?
    public var imageName: String?
    public let createdAt: Date
    
    // Convenience property for backward compatibility and text shortcuts
    public var replacement: String {
        get { textContent ?? "" }
        set { textContent = newValue }
    }
    
    public init(
        id: UUID = UUID(),
        shortcut: String,
        type: ShortcutType = .text,
        textContent: String? = nil,
        imageAsset: String? = nil,
        imageName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.shortcut = shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
        self.type = type
        self.textContent = textContent
        self.imageAsset = imageAsset
        self.imageName = imageName
        self.createdAt = createdAt
    }
    
    /// Convenience initializer for text shortcuts
    public init(
        id: UUID = UUID(),
        shortcut: String,
        replacement: String,
        createdAt: Date = Date()
    ) {
        self.init(
            id: id,
            shortcut: shortcut,
            type: .text,
            textContent: replacement,
            imageAsset: nil,
            imageName: nil,
            createdAt: createdAt
        )
    }
    
    /// Normalizes a shortcut for case-insensitive comparison and storage lookup.
    public var normalizedKey: String {
        return shortcut.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    /// Validates shortcut input.
    public static func validate(
        shortcut: String,
        type: ShortcutType,
        textContent: String?,
        imageAsset: String?,
        existing: [TextShortcut],
        editingId: UUID? = nil
    ) -> String? {
        let trimmedShortcut = shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedShortcut.isEmpty {
            return "Shortcut cannot be empty."
        }
        
        if trimmedShortcut.contains(where: { $0.isWhitespace }) {
            return "Shortcut cannot contain spaces."
        }
        
        let normalized = trimmedShortcut.lowercased()
        let isDuplicate = existing.contains { other in
            if let editingId = editingId, other.id == editingId {
                return false
            }
            return other.normalizedKey == normalized
        }
        
        if isDuplicate {
            return "A shortcut for '\(trimmedShortcut)' already exists."
        }
        
        switch type {
        case .text:
            if textContent == nil {
                return "Replacement text cannot be missing."
            }
        case .image:
            if imageAsset == nil || imageAsset!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Please choose an image for this shortcut."
            }
        }
        
        return nil
    }
}
