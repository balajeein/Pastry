import SwiftUI

struct ImageThumbnailView: View {
    let storagePath: String
    @State private var thumbnail: NSImage? = nil
    
    var body: some View {
        Group {
            if let image = thumbnail {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 36)
                    .clipped()
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                    )
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 50, height: 36)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    )
                    .onAppear {
                        loadThumbnail()
                    }
            }
        }
    }
    
    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInteractive).async {
            if let data = ImageStorage.shared.loadThumbnail(path: storagePath),
               let img = NSImage(data: data) {
                DispatchQueue.main.async {
                    self.thumbnail = img
                }
            }
        }
    }
}

public struct ClipboardRowView: View {
    let item: ClipboardItem
    let isSelected: Bool
    
    public var body: some View {
        HStack(spacing: 12) {
            // Left icon or thumbnail
            if item.type == .image, let path = item.storagePath {
                ImageThumbnailView(storagePath: path)
            } else {
                Circle()
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.primary.opacity(0.04))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: typeIconName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isSelected ? .white : .secondary)
                    )
            }
            
            // Content text
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Relative time representation
            Text(RelativeFormatter.format(item.timestamp))
                .font(.system(size: 10, weight: .light))
                .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
    }
    
    private var typeIconName: String {
        switch item.type {
        case .text:
            return "text.alignleft"
        case .url:
            return "link"
        case .file:
            return "doc.on.doc"
        case .image:
            return "photo"
        case .other:
            return "square.stack.3d.up"
        }
    }
}
