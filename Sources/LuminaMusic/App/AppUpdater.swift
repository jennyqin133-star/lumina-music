import Foundation
import SwiftUI
import Sparkle

/// SwiftUI-friendly wrapper around Sparkle's SPUStandardUpdaterController.
///
/// Created once at app launch; lifetime of the controller mirrors the lifetime
/// of the app process. The `canCheck` property is observable so the "Check for
/// Updates…" menu item stays in sync with whether Sparkle is willing to run a
/// check right now (e.g. it's disabled while an update is already downloading).
final class AppUpdater: NSObject, ObservableObject {
    static let shared = AppUpdater()

    private let updaterController: SPUStandardUpdaterController

    @Published private(set) var canCheck: Bool = true

    private override init() {
        // startingUpdater: true → Sparkle begins its initial check on launch
        //                         (subject to SUEnableAutomaticChecks + interval).
        // updaterDelegate / userDriverDelegate: nil → use Sparkle's defaults.
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
        // Re-evaluate canCheck whenever Sparkle's state changes
        self.updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheck)
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
