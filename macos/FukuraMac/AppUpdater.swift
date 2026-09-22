import AppKit
import Sparkle

@MainActor
final class AppUpdater: NSObject, NSMenuItemValidation {
    private var controller: SPUStandardUpdaterController?

    func start() {
        guard controller == nil, Bundle.main.bundleURL.pathExtension == "app",
              UpdateConfiguration.isValid(
                feed: Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
                publicKey: Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
              ) else { return }
        let updater = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil
        )
        controller = updater
        updater.startUpdater()
    }

    func addMenuItems(to menu: NSMenu) {
        menu.addItem(NSMenuItem.separator())
        for (title, action) in [
            ("アップデートを確認…", #selector(checkForUpdates(_:))),
            ("自動更新", #selector(toggleAutomaticUpdates(_:)))
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
    }

    @objc private func checkForUpdates(_ sender: NSMenuItem) {
        guard let controller else {
            let alert = NSAlert()
            alert.messageText = "このビルドでは自動更新を利用できません"
            alert.informativeText = "更新に対応した正式配布版をインストールしてください。"
            alert.runModal()
            return
        }
        controller.checkForUpdates(sender)
    }

    @objc private func toggleAutomaticUpdates(_ sender: NSMenuItem) {
        guard let updater = controller?.updater else { return }
        let enabled = !(updater.automaticallyChecksForUpdates && updater.automaticallyDownloadsUpdates)
        // Change persisted Sparkle preferences only in response to a user action.
        updater.automaticallyDownloadsUpdates = enabled
        updater.automaticallyChecksForUpdates = enabled
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleAutomaticUpdates(_:)) {
            let enabled = controller.map {
                $0.updater.automaticallyChecksForUpdates && $0.updater.automaticallyDownloadsUpdates
            } ?? false
            menuItem.state = enabled ? .on : .off
            return controller != nil
        }
        return controller?.updater.canCheckForUpdates ?? true
    }
}
