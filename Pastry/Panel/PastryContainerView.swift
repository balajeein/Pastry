import SwiftUI

public enum ScreenshotButtonSide {
    case left
    case right
}

/// Unified container view hosting the Clipboard Card and the adjacent Floating Screenshot Button.
/// Rendering both within one transparent window eliminates all child-window artifacts and white corners.
public struct PastryContainerView: View {
    @ObservedObject var viewModel: ClipboardPanelViewModel
    let buttonSide: ScreenshotButtonSide
    let onClose: () -> Void
    let onScreenshot: () -> Void
    
    public init(
        viewModel: ClipboardPanelViewModel,
        buttonSide: ScreenshotButtonSide = .right,
        onClose: @escaping () -> Void,
        onScreenshot: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.buttonSide = buttonSide
        self.onClose = onClose
        self.onScreenshot = onScreenshot
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if buttonSide == .left {
                FloatingScreenshotButtonView(action: onScreenshot)
                    .padding(.top, 6)
            }
            
            // Main Clipboard Card
            ClipboardPanelView(viewModel: viewModel, onClose: onClose)
                .frame(width: 360, height: 450)
                .background(
                    AppleGlassEffectView(cornerRadius: 16)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                )
            
            if buttonSide == .right {
                FloatingScreenshotButtonView(action: onScreenshot)
                    .padding(.top, 6)
            }
        }
        .padding(18) // Ambient padding for soft drop shadows and hover scaling
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
