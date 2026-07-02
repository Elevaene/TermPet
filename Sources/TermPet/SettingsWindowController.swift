import AppKit
import SwiftUI
import TermPetCore

@MainActor
final class SettingsWindowController: NSObject {
    private let model: AppModel
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
        super.init()
    }

    func showWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate()
            return
        }

        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "TermPet 设置"
        settingsWindow.center()
        settingsWindow.isReleasedWhenClosed = FloatingPanelLifecyclePolicy.appHosted.releaseWhenClosed
        settingsWindow.contentView = NSHostingView(
            rootView: SettingsView(model: model) { [weak settingsWindow] in
                settingsWindow?.close()
            }
        )
        settingsWindow.makeKeyAndOrderFront(nil)
        window = settingsWindow
        NSApplication.shared.activate()
    }
}
