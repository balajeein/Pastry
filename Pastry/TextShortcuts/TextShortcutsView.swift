import SwiftUI

/// Floating management view for Text Shortcuts (listing, adding, editing, and deleting).
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
            $0.replacement.localizedCaseInsensitiveContains(searchText)
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
        .frame(width: 400, height: 380)
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
                onSave: { shortcut, replacement in
                    if let editing = editingShortcut {
                        let res = store.update(id: editing.id, shortcut: shortcut, replacement: replacement)
                        if res.success {
                            isShowingEditor = false
                            selectedShortcutId = editing.id
                        }
                        return res.error
                    } else {
                        let res = store.add(shortcut: shortcut, replacement: replacement)
                        if res.success {
                            isShowingEditor = false
                        }
                        return res.error
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
            // LEFT SIDE: Shortcut
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
            
            // RIGHT SIDE: Replacement content (truncated with ellipsis if long)
            Text(shortcut.replacement.replacingOccurrences(of: "\n", with: " ↵ "))
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .white.opacity(0.92) : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Shortcut Editor Sheet (Add / Edit)

private struct ShortcutEditorSheet: View {
    let existingShortcut: TextShortcut?
    let onSave: (String, String) -> String?
    let onCancel: () -> Void
    
    @State private var shortcutText: String = ""
    @State private var replacementText: String = ""
    @State private var errorMessage: String? = nil
    
    init(
        existingShortcut: TextShortcut?,
        onSave: @escaping (String, String) -> String?,
        onCancel: @escaping () -> Void
    ) {
        self.existingShortcut = existingShortcut
        self.onSave = onSave
        self.onCancel = onCancel
        _shortcutText = State(initialValue: existingShortcut?.shortcut ?? "")
        _replacementText = State(initialValue: existingShortcut?.replacement ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(existingShortcut == nil ? "Add Text Shortcut" : "Edit Text Shortcut")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
            
            // Shortcut Input
            VStack(alignment: .leading, spacing: 4) {
                Text("Shortcut")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("e.g. Myemail", text: $shortcutText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 13, design: .monospaced))
            }
            
            // Replacement Input
            VStack(alignment: .leading, spacing: 4) {
                Text("Replace with")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                if #available(macOS 13.0, *) {
                    TextField("e.g. balajee@gmail.com", text: $replacementText, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 12))
                } else {
                    TextEditor(text: $replacementText)
                        .frame(height: 70)
                        .font(.system(size: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
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
                    let err = onSave(shortcutText, replacementText)
                    errorMessage = err
                }
                .keyboardShortcut(.defaultAction)
                .disabled(shortcutText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 6)
        }
        .padding(18)
        .frame(width: 340)
    }
}
