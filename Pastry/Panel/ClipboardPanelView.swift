import SwiftUI

public class ClipboardPanelViewModel: ObservableObject {
    @Published public var searchText = "" {
        didSet {
            // Reset selection when search term changes
            selectedIndex = 0
        }
    }
    @Published public var selectedIndex = 0
    @Published private var store = ClipboardStore.shared
    
    public init() {}
    
    public var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return store.items
        }
        return store.items.filter { item in
            item.displayTitle.localizedCaseInsensitiveContains(searchText) ||
            item.subtitle?.localizedCaseInsensitiveContains(searchText) == true ||
            item.textContent?.localizedCaseInsensitiveContains(searchText) == true ||
            item.calculationResult?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    public func moveSelectionDown() {
        let count = filteredItems.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + 1) % count
    }
    
    public func moveSelectionUp() {
        let count = filteredItems.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex - 1 + count) % count
    }
    
    public func selectAndPaste(onClose: () -> Void) {
        let items = filteredItems
        guard selectedIndex >= 0 && selectedIndex < items.count else { return }
        let selectedItem = items[selectedIndex]
        pasteItem(selectedItem, onClose: onClose)
    }
    
    public func pasteItem(_ item: ClipboardItem, onClose: () -> Void) {
        onClose()
        PasteService.shared.restoreActiveAppAndPaste(item: item) { _ in }
    }
    
    public func pasteAnswer(for item: ClipboardItem, onClose: () -> Void) {
        guard let answer = item.calculationResult else { return }
        let answerItem = ClipboardItem(
            type: .text,
            textContent: answer,
            displayTitle: answer,
            subtitle: "Calculated Answer"
        )
        onClose()
        PasteService.shared.restoreActiveAppAndPaste(item: answerItem) { _ in }
    }
}

public struct ClipboardPanelView: View {
    @StateObject private var viewModel: ClipboardPanelViewModel
    let onClose: () -> Void
    
    public init(viewModel: ClipboardPanelViewModel = ClipboardPanelViewModel(), onClose: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13, weight: .semibold))
                
                if #available(macOS 12.0, *) {
                    TextField("Search clipboard...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .onSubmit {
                            viewModel.selectAndPaste(onClose: onClose)
                        }
                } else {
                    TextField("Search clipboard...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary.opacity(0.8))
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            
            Divider()
                .background(Color.primary.opacity(0.08))
            
            // Unified Chronological History List
            let items = viewModel.filteredItems
            if items.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: viewModel.searchText.isEmpty ? "clipboard" : "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    Text(viewModel.searchText.isEmpty ? "Clipboard empty" : "No matching items")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if viewModel.searchText.isEmpty {
                        Text("Copy something and it'll appear here.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .padding(.horizontal, 24)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                                ClipboardRowView(
                                    item: item,
                                    isSelected: idx == viewModel.selectedIndex,
                                    onTapLeft: {
                                        viewModel.selectedIndex = idx
                                        viewModel.pasteItem(item, onClose: onClose)
                                    },
                                    onTapRight: {
                                        viewModel.selectedIndex = idx
                                        viewModel.pasteAnswer(for: item, onClose: onClose)
                                    }
                                )
                                .id(idx)
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: viewModel.selectedIndex) { newIndex in
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
