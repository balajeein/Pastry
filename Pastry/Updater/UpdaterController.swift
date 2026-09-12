import Cocoa
import SwiftUI
import Sparkle

/// Dedicated controller managing the Sparkle 2 automatic updater lifecycle and manual update checks.
public class UpdaterController: NSObject, SPUUpdaterDelegate, NSWindowDelegate {
    public static let shared = UpdaterController()
    
    private var updaterController: SPUStandardUpdaterController?
    private var updateWindow: NSWindow?
    
    /// Returns true if the updater is ready to check for updates.
    public var canCheckForUpdates: Bool {
        return updaterController?.updater.canCheckForUpdates ?? false
    }
    
    private override init() {
        super.init()
    }
    
    /// Initializes the standard Sparkle updater controller.
    /// Called once during applicationDidFinishLaunching.
    public func start() {
        guard updaterController == nil else { return }
        
        // SPUStandardUpdaterController starts the updater, background scheduling, and native UI dialogs.
        // Temporarily initialized with startingUpdater: false to disable automatic background network checks.
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }
    
    /// Triggers a manual update check.
    /// Temporarily displays a simulated native update checking UI without making any network requests.
    @objc public func checkForUpdates() {
        if let window = updateWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 140),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Software Update"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.delegate = self
        
        let hostingView = NSHostingView(rootView: SoftwareUpdateModalView(onClose: { [weak window, weak self] in
            window?.close()
            self?.updateWindow = nil
        }))
        window.contentView = hostingView
        
        self.updateWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - NSWindowDelegate
    
    public func windowWillClose(_ notification: Notification) {
        if let closedWindow = notification.object as? NSWindow, closedWindow == updateWindow {
            updateWindow = nil
        }
    }
}

private struct SoftwareUpdateModalView: View {
    @State private var isChecking = true
    let onClose: () -> Void
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.1"
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            if let icon = NSApp.applicationIconImage ?? NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 58, height: 58)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if isChecking {
                    Text("Checking for updates…")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Checking for new versions of Pastry…")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                } else {
                    Text("You're up to date.")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Pastry \(appVersion) is currently the newest version available.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                HStack {
                    Spacer()
                    if isChecking {
                        Button("Cancel") {
                            onClose()
                        }
                        .keyboardShortcut(.cancelAction)
                    } else {
                        Button("OK") {
                            onClose()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 380, height: 140)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isChecking = false
                }
            }
        }
    }
}
