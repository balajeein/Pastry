import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Floating management view for Text & Image Shortcuts.
public struct TextShortcutsView: View {
    @ObservedObject var store = TextShortcutStore.shared
    @State private var selectedShortcutId: UUID?
    @State private var isShowingEditor = false
    @State private var editingShortcut: TextShortcut?
    @State private var searchText = ""
    let onClose: () -> Void
    
    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    private var filteredShortcuts: [TextShortcut] {
        if searchText.isEmpty {
            return store.shortcuts
        }
        return store.shortcuts.filter {
            $0.shortcut.localizedCaseInsensitiveContains(searchText) ||
            ($0.textContent?.localizedCaseInsensitiveContains(searchText) == true) ||
            ($0.imageName?.localizedCaseInsensitiveContains(searchText) == true)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Text Shortcuts")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            // Search / Filter Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                TextField("Search shortcuts...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 12))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.06))
            .cornerRadius(8)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.primary.opacity(0.08))
            
            // Shortcut List
            if filteredShortcuts.isEmpty {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "character.cursor.ibeam")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text(searchText.isEmpty ? "No Shortcuts Configured" : "No Matching Shortcuts")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Type shortcut then press ⌥ + Space to expand.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.horizontal, 20)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredShortcuts) { item in
                            ShortcutRowView(
                                shortcut: item,
                                isSelected: selectedShortcutId == item.id,
                                onSelect: {
                                    selectedShortcutId = item.id
                                },
                                onDoubleClick: {
                                    editingShortcut = item
                                    isShowingEditor = true
                                }
                            )
                        }
                    }
                    .padding(8)
                }
            }
            
            Divider()
                .background(Color.primary.opacity(0.08))
            
            // Bottom Action Bar: [ − ] [ + ]
            HStack(spacing: 12) {
                // Delete button (−)
                Button(action: deleteSelected) {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 28, height: 24)
                        .background(Color.primary.opacity(selectedShortcutId != nil ? 0.10 : 0.04))
                        .cornerRadius(6)
                        .foregroundColor(selectedShortcutId != nil ? .primary : .secondary.opacity(0.4))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(selectedShortcutId == nil)
                .help("Delete selected shortcut")
                
                // Add button (+)
                Button(action: {
                    editingShortcut = nil
                    isShowingEditor = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 28, height: 24)
                        .background(Color.primary.opacity(0.10))
                        .cornerRadius(6)
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Add new shortcut")
                
                Spacer()
                
                Text("Press ⌥ + Space to expand")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 420, height: 390)
        .background(
            AppleGlassEffectView(cornerRadius: 16)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
        .sheet(isPresented: $isShowingEditor) {
            ShortcutEditorSheet(
                existingShortcut: editingShortcut,
                onSave: { shortcut, type, textContent, assetFilename, imageName in
                    if let editing = editingShortcut {
                        if type == .text {
                            let res = store.updateTextShortcut(id: editing.id, shortcut: shortcut, replacement: textContent ?? "")
                            if res.success {
                                isShowingEditor = false
                                selectedShortcutId = editing.id
                            }
                            return res.error
                        } else {
                            guard let asset = assetFilename, let name = imageName else {
                                return "Please choose an image."
                            }
                            let res = store.updateImageShortcut(id: editing.id, shortcut: shortcut, assetFilename: asset, originalName: name)
                            if res.success {
                                isShowingEditor = false
                                selectedShortcutId = editing.id
                            }
                            return res.error
                        }
                    } else {
                        if type == .text {
                            let res = store.addTextShortcut(shortcut: shortcut, replacement: textContent ?? "")
                            if res.success {
                                isShowingEditor = false
                            }
                            return res.error
                        } else {
                            guard let asset = assetFilename, let name = imageName else {
                                return "Please choose an image."
                            }
                            let res = store.addImageShortcut(shortcut: shortcut, assetFilename: asset, originalName: name)
                            if res.success {
                                isShowingEditor = false
                            }
                            return res.error
                        }
                    }
                },
                onCancel: {
                    isShowingEditor = false
                }
            )
        }
    }
    
    private func deleteSelected() {
        guard let id = selectedShortcutId else { return }
        store.delete(id: id)
        selectedShortcutId = nil
    }
}

// MARK: - Shortcut Row View

private struct ShortcutRowView: View {
    let shortcut: TextShortcut
    let isSelected: Bool
    let onSelect: () -> Void
    let onDoubleClick: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // LEFT SIDE: Shortcut Pill
            Text(shortcut.shortcut)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.blue.opacity(0.85) : Color.primary.opacity(0.08))
                )
                .frame(minWidth: 90, alignment: .leading)
            
            // RIGHT SIDE: Content (Text or Image Thumbnail)
            if shortcut.type == .text {
                Text((shortcut.textContent ?? "").replacingOccurrences(of: "\n", with: " ↵ "))
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white.opacity(0.92) : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 6) {
                    if let asset = shortcut.imageAsset,
                       let thumb = ShortcutAssetStorage.shared.loadThumbnailImage(assetFilename: asset) {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .cornerRadius(4)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 12))
                            .foregroundColor(isSelected ? .white : .secondary)
                    }
                    
                    Text(shortcut.imageName ?? "Image Asset")
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .white.opacity(0.92) : .secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.35) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onDoubleClick()
        }
        .onTapGesture(count: 1) {
            onSelect()
        }
    }
}

// MARK: - Native Multiline NSTextView Wrapper

/// Native AppKit NSTextView wrapped in an NSScrollView for 100% native macOS text editing,
/// paste (⌘V), copy (⌘C), select all (⌘A), scrolling, and newlines preservation.
public struct NativeMultilineTextEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "e.g. name@example.com"
    
    public init(text: Binding<String>, placeholder: String = "e.g. name@example.com") {
        self._text = text
        self.placeholder = placeholder
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isSelectable = true
        textView.isEditable = true
        textView.font = NSFont.systemFont(ofSize: 12)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.clear
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.string = text
        
        // Sizing & container setup
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }
    
    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }
    
    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeMultilineTextEditor
        weak var textView: NSTextView?
        
        init(_ parent: NativeMultilineTextEditor) {
            self.parent = parent
        }
        
        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

// MARK: - Shortcut Editor Sheet (Add / Edit)

private struct ShortcutEditorSheet: View {
    let existingShortcut: TextShortcut?
    let onSave: (String, ShortcutType, String?, String?, String?) -> String?
    let onCancel: () -> Void
    
    @State private var shortcutText: String = ""
    @State private var shortcutType: ShortcutType = .text
    @State private var replacementText: String = ""
    @State private var assetFilename: String? = nil
    @State private var originalImageName: String? = nil
    @State private var previewImage: NSImage? = nil
    @State private var errorMessage: String? = nil
    
    init(
        existingShortcut: TextShortcut?,
        onSave: @escaping (String, ShortcutType, String?, String?, String?) -> String?,
        onCancel: @escaping () -> Void
    ) {
        self.existingShortcut = existingShortcut
        self.onSave = onSave
        self.onCancel = onCancel
        _shortcutText = State(initialValue: existingShortcut?.shortcut ?? "")
        _shortcutType = State(initialValue: existingShortcut?.type ?? .text)
        _replacementText = State(initialValue: existingShortcut?.textContent ?? "")
        _assetFilename = State(initialValue: existingShortcut?.imageAsset)
        _originalImageName = State(initialValue: existingShortcut?.imageName)
        
        if let asset = existingShortcut?.imageAsset,
           let thumb = ShortcutAssetStorage.shared.loadThumbnailImage(assetFilename: asset) {
            _previewImage = State(initialValue: thumb)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(existingShortcut == nil ? "Add Shortcut" : "Edit Shortcut")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
            
            // Shortcut Input
            VStack(alignment: .leading, spacing: 4) {
                Text("Shortcut")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("e.g. myemail or sign", text: $shortcutText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 13, design: .monospaced))
            }
            
            // Type Selector (Text / Image)
            VStack(alignment: .leading, spacing: 4) {
                Text("Type")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Picker("", selection: $shortcutType) {
                    Text("Text").tag(ShortcutType.text)
                    Text("Image").tag(ShortcutType.image)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Content Input depending on Type
            if shortcutType == .text {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Replace with")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    NativeMultilineTextEditor(text: $replacementText, placeholder: "e.g. name@example.com")
                        .frame(height: 120)
                        .padding(6)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.18), lineWidth: 1)
                        )
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Image Content")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if let preview = previewImage {
                        HStack(spacing: 12) {
                            Image(nsImage: preview)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 54, height: 54)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(originalImageName ?? "Selected Image")
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                
                                Button("Change Image…") {
                                    chooseImage()
                                }
                                .font(.system(size: 11))
                            }
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(8)
                    } else {
                        Button(action: chooseImage) {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text("Choose Image…")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
            
            // Action Buttons
            HStack {
                Spacer()
                
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    let err = onSave(shortcutText, shortcutType, replacementText, assetFilename, originalImageName)
                    errorMessage = err
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    shortcutText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    (shortcutType == .image && assetFilename == nil)
                )
            }
            .padding(.top, 6)
        }
        .padding(18)
        .frame(width: 380)
    }
    
    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select an image for this shortcut"
        
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = [.image, .png, .jpeg, .heic, .gif, .tiff, .webP]
        } else {
            panel.allowedFileTypes = ["png", "jpg", "jpeg", "heic", "gif", "tiff", "webp"]
        }
        
        if panel.runModal() == .OK, let url = panel.url {
            if let result = ShortcutAssetStorage.shared.importImage(from: url) {
                assetFilename = result.assetFilename
                originalImageName = result.originalName
                previewImage = ShortcutAssetStorage.shared.loadThumbnailImage(assetFilename: result.assetFilename)
                errorMessage = nil
            } else {
                errorMessage = "Failed to import selected image. Please ensure it is a valid image file."
            }
        }
    }
}
