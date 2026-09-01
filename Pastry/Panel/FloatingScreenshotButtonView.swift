import SwiftUI
import Cocoa

/// Custom NSVisualEffectView wrapper that strictly forces a circular CoreAnimation layer mask
/// so the WindowServer material backdrop is perfectly circular with zero square corners.
public struct AppleGlassEffectView: NSViewRepresentable {
    public var cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 23) {
        self.cornerRadius = cornerRadius
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.wantsLayer = true
        nsView.layer?.cornerRadius = cornerRadius
        nsView.layer?.masksToBounds = true
    }
}

/// Custom circular Apple Glass floating screenshot button.
public struct FloatingScreenshotButtonView: View {
    let action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false
    
    public static let buttonDiameter: CGFloat = 46
    
    public init(action: @escaping () -> Void) {
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            ZStack {
                // 1. Native Apple Blurred Glass (strictly circular)
                AppleGlassEffectView(cornerRadius: Self.buttonDiameter / 2)
                    .frame(width: Self.buttonDiameter, height: Self.buttonDiameter)
                    .clipShape(Circle())
                
                // 2. Translucent dark glass tint
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(isHovered ? 0.22 : 0.10),
                                Color.black.opacity(isHovered ? 0.20 : 0.35)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: Self.buttonDiameter, height: Self.buttonDiameter)
                
                // 3. Top specular light sheen (glass reflection)
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.white.opacity(isHovered ? 0.30 : 0.16), location: 0.0),
                                .init(color: Color.clear, location: 0.50)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: Self.buttonDiameter, height: Self.buttonDiameter)
                
                // 4. Specular Glass Rim / Border
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.white.opacity(isHovered ? 0.65 : 0.45), location: 0.0),
                                .init(color: Color.white.opacity(isHovered ? 0.30 : 0.18), location: 0.5),
                                .init(color: Color.white.opacity(isHovered ? 0.15 : 0.08), location: 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.0
                    )
                    .frame(width: Self.buttonDiameter, height: Self.buttonDiameter)
                
                // 5. Camera Viewfinder Icon (crisp white with subtle depth shadow)
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(Color.white.opacity(isHovered ? 1.0 : 0.95))
                    .shadow(color: Color.black.opacity(0.4), radius: 1, x: 0, y: 1)
            }
            .frame(width: Self.buttonDiameter, height: Self.buttonDiameter)
            .shadow(color: Color.black.opacity(0.40), radius: 8, x: 0, y: 3)
            .scaleEffect(isPressed ? 0.92 : (isHovered ? 1.06 : 1.0))
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .animation(.easeInOut(duration: 0.10), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .help("Scroll Screenshot")
    }
}
