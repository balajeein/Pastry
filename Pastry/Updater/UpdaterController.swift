import Cocoa
import Sparkle

/// Dedicated controller managing the Sparkle 2 automatic updater lifecycle and manual update checks.
public class UpdaterController: NSObject, SPUUpdaterDelegate {
    public static let shared = UpdaterController()
    
    private var updaterController: SPUStandardUpdaterController?
    
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
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }
    
    /// Triggers a manual update check and presents the standard native Sparkle update dialog.
    @objc public func checkForUpdates() {
        if let controller = updaterController {
            controller.checkForUpdates(nil)
        } else {
            start()
            updaterController?.checkForUpdates(nil)
        }
    }
}
