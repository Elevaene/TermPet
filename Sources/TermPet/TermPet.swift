import AppKit
import SwiftUI
import TermPetCore

@main
struct TermPetLauncher {
    @MainActor private static let delegate = AppDelegate()

    @MainActor static func main() {
        RuntimeLogRedirector.installUnlessDebugEnabled()
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore()
    private lazy var model = AppModel(settingsStore: settingsStore)
    private lazy var petWindowController = PetWindowController(model: model)
    private lazy var statusBarController = StatusBarController(model: model)
    private lazy var settingsWindowControllerHolder = SettingsWindowController(model: model)
    private lazy var hotKeyController = GlobalHotKeyController(model: model)

    func applicationDidFinishLaunching(_ notification: Notification) {
        petWindowController.showWindow()
        statusBarController.onOpenSettings = { [weak self] in
            self?.settingsWindowControllerHolder.showWindow()
        }
        statusBarController.install()
        hotKeyController.install()
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }
}
