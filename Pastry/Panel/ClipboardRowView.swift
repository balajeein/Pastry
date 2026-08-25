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
            }
        }
        .onAppear {
            loadThumbnail(path: storagePath)
        }
        .onChange(of: storagePath) { _, newPath in
            loadThumbnail(path: newPath)
        }
    }
    
    private func loadThumbnail(path: String) {
        DispatchQueue.global(qos: .userInteractive).async {
            if let data = ImageStorage.shared.loadThumbnail(path: path),
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
    var onTapLeft: (() -> Void)? = nil
    var onTapRight: (() -> Void)? = nil
    
    @State private var isLeftHovered = false
    @State private var isRightHovered = false
    
    public var body: some View {
        if let answer = item.calculationResult {
            // Split horizontal layout for mathematical expression
            HStack(spacing: 0) {
                // LEFT SECTION: Original Expression
                HStack(spacing: 10) {
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.15) : Color.primary.opacity(0.04))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "equal.circle")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(isSelected ? .white : .secondary)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayTitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(isSelected ? .white : .primary)
                            .lineLimit(1)
                        
                        Text("Copy text")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isLeftHovered ? (isSelected ? Color.white.opacity(0.2) : Color.primary.opacity(0.06)) : Color.clear)
                )
                .contentShape(Rectangle())
                .onHover { isLeftHovered = $0 }
                .onTapGesture {
                    onTapLeft?()
                }
                
                // VERTICAL DIVIDER
                Rectangle()
                    .fill(isSelected ? Color.white.opacity(0.3) : Color.primary.opacity(0.12))
                    .frame(width: 1)
                    .padding(.vertical, 6)
                
                // RIGHT SECTION: Calculated Answer
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(answer)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .accentColor)
                            .lineLimit(1)
                        
                        Text("Answer")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    
                    Text(RelativeFormatter.format(item.timestamp))
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRightHovered ? (isSelected ? Color.white.opacity(0.2) : Color.primary.opacity(0.06)) : Color.clear)
                )
                .contentShape(Rectangle())
                .onHover { isRightHovered = $0 }
                .onTapGesture {
                    onTapRight?()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        } else {
            // Standard single row layout for non-mathematical items
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
            .onTapGesture {
                onTapLeft?()
            }
        }
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
