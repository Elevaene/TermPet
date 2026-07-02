import AppKit

@MainActor
final class StatusBarController {
    private let model: AppModel
    private var item: NSStatusItem?
    var onOpenSettings: (() -> Void)?

    init(model: AppModel) {
        self.model = model
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVisibilityChanged),
            name: .termPetVisibilityChanged,
            object: nil
        )
    }

    func install() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🐾"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "暂停监听", action: #selector(toggleListening), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "隐藏宠物", action: #selector(togglePetVisibility), keyEquivalent: "h"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))

        for menuItem in menu.items {
            menuItem.target = self
        }

        statusItem.menu = menu
        item = statusItem
        refreshMenu()
    }

    func refreshMenu() {
        guard let menu = item?.menu else { return }
        menu.item(at: 0)?.title = model.settings.isListeningPaused ? "继续监听" : "暂停监听"
        menu.item(at: 1)?.title = model.isPetHidden ? "显示宠物" : "隐藏宠物"
    }

    @objc private func toggleListening() {
        model.toggleListeningPaused()
        refreshMenu()
    }

    @objc private func togglePetVisibility() {
        model.setPetHidden(!model.isPetHidden)
        refreshMenu()
        NotificationCenter.default.post(name: .termPetVisibilityChanged, object: nil)
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func handleVisibilityChanged() {
        refreshMenu()
    }
}

extension Notification.Name {
    static let termPetVisibilityChanged = Notification.Name("TermPetVisibilityChanged")
    static let termPetTogglePanel = Notification.Name("TermPetTogglePanel")
}
