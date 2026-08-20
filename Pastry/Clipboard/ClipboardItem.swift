import Foundation

public enum ClipboardItemType: String, Codable {
    case text
    case image
    case url
    case file
    case other
}

public struct ClipboardItem: Codable, Identifiable, Equatable {
    public let id: UUID
    public let type: ClipboardItemType
    public let timestamp: Date
    public let textContent: String?
    public let storagePath: String? // Relative path to data storage on disk
    public let displayTitle: String
    public let subtitle: String?
    public let representations: [String: Data]? // Extracted raw pasteboard data (small sizes only)
    
    public init(
        id: UUID = UUID(),
        type: ClipboardItemType,
        timestamp: Date = Date(),
        textContent: String? = nil,
        storagePath: String? = nil,
        displayTitle: String,
        subtitle: String? = nil,
        representations: [String: Data]? = nil
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.textContent = textContent
        self.storagePath = storagePath
        self.displayTitle = displayTitle
        self.subtitle = subtitle
        self.representations = representations
    }
    
    public static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        // Core equality check for deduplication
        if lhs.type != rhs.type { return false }
        switch lhs.type {
        case .text, .url, .file:
            return lhs.textContent == rhs.textContent
        case .image, .other:
            // For images/others, we compare display title and subtitle or storage paths if available.
            // If they are exactly the same size/hash (reflected in subtitle or title), they are duplicates.
            return lhs.displayTitle == rhs.displayTitle && lhs.subtitle == rhs.subtitle
        }
    }
}
