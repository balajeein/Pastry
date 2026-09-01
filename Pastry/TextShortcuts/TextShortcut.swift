import Foundation

/// Represents a user-defined text shortcut with case-insensitive trigger expansion.
public struct TextShortcut: Identifiable, Codable, Equatable {
    public let id: UUID
    public var shortcut: String
    public var replacement: String
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        shortcut: String,
        replacement: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.shortcut = shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
        self.replacement = replacement
        self.createdAt = createdAt
    }
    
    /// Normalizes a shortcut for case-insensitive comparison and storage lookup.
    public var normalizedKey: String {
        return shortcut.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    /// Validates shortcut input.
    public static func validate(
        shortcut: String,
        replacement: String,
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
        
        return nil
    }
}
