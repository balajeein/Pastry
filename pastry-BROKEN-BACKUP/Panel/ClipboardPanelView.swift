import SwiftUI

/// Distinguishes between a normal clipboard item and a calculated result.
/// The panel uses this to decide which paste mode to invoke.
public enum PastryAction: Identifiable {
    case clipboardItem(ClipboardItem)
    case calculation(expression: String, result: String)
    
    public var id: String {
        switch self {
        case .clipboardItem(let item): return item.id.uuidString
        case .calculation(_, let result): return "calc-\(result)"
        }
    }
}

public class ClipboardPanelViewModel: ObservableObject {
    @Published public var searchText = "" {
        didSet {
            selectedIndex = 0
        }
    }
    @Published public var selectedIndex = 0
    @Published private var store = ClipboardStore.shared
    
    /// Set when the panel opens if the user had a math expression selected
    @Published public var calculationResult: (expression: String, result: String)?
    
    public init() {}
    
    /// All displayable actions: calculation (if any) at the top, then filtered clipboard items
    public var allActions: [PastryAction] {
        var actions: [PastryAction] = []
        
        // Show calculation result at the top if available and search is empty or matches
        if let calc = calculationResult {
            if searchText.isEmpty ||
               calc.expression.localizedCaseInsensitiveContains(searchText) ||
               calc.result.localizedCaseInsensitiveContains(searchText) {
                actions.append(.calculation(expression: calc.expression, result: calc.result))
            }
        }
        
        // Append filtered clipboard history items
        let items = filteredItems
        for item in items {
            actions.append(.clipboardItem(item))
        }
        
        return actions
    }
    
    public var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return store.items
        }
        return store.items.filter { item in
            item.displayTitle.localizedCaseInsensitiveContains(searchText) ||
            item.subtitle?.localizedCaseInsensitiveContains(searchText) == true ||
            item.textContent?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    public func moveSelectionDown() {
        let count = allActions.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + 1) % count
    }
    
    public func moveSelectionUp() {
        let count = allActions.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex - 1 + count) % count
    }
    
    public func selectAndPaste(onClose: () -> Void) {
        let actions = allActions
        guard selectedIndex >= 0 && selectedIndex < actions.count else { return }
        let selected = actions[selectedIndex]
        onClose()
        
        switch selected {
        case .clipboardItem(let item):
            // Mode 1: Normal paste — replaces the current selection (unchanged behavior)
            PasteService.shared.restoreActiveAppAndPaste(item: item) { _ in }
            
        case .calculation(_, let result):
            // Mode 2: Insert after selection — preserves the original expression
            PasteService.shared.restoreActiveAppAndInsertAfterSelection(resultText: result) { _ in }
        }
    }
    
    /// Called when the panel opens to detect a math expression in the user's selection
    public func detectCalculation() {
        calculationResult = nil
        guard let selectedText = PasteService.shared.capturedSelectedText else { return }
        calculationResult = CalculationService.shared.evaluate(selectedText)
    }
}

// MARK: - Calculation Row View

struct CalculationRowView: View {
    let expression: String
    let result: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isSelected ? Color.white.opacity(0.15) : Color.orange.opacity(0.12))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "equal")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isSelected ? .white : .orange)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Text(expression + " =")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text("Insert")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary.opacity(0.7))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.white.opacity(0.15) : Color.primary.opacity(0.05))
                )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.orange : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Panel View

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
                
                TextField("Search clipboard...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .onSubmit {
                        viewModel.selectAndPaste(onClose: onClose)
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
            
            // Unified list: calculation result (if any) + clipboard history
            let actions = viewModel.allActions
            if actions.isEmpty {
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
                            ForEach(0..<actions.count, id: \.self) { idx in
                                let action = actions[idx]
                                Group {
                                    switch action {
                                    case .clipboardItem(let item):
                                        ClipboardRowView(item: item, isSelected: idx == viewModel.selectedIndex)
                                    case .calculation(let expr, let result):
                                        CalculationRowView(expression: expr, result: result, isSelected: idx == viewModel.selectedIndex)
                                    }
                                }
                                .id(idx)
                                .onTapGesture {
                                    viewModel.selectedIndex = idx
                                    viewModel.selectAndPaste(onClose: onClose)
                                }
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: viewModel.selectedIndex) { _, newIndex in
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
