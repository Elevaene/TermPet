import AppKit
import SwiftUI
import TermPetCore

@MainActor
final class PetWindowController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private var window: NSWindow?
    private var infoPanel: NSWindow?
    private var followTimer: DispatchSourceTimer?

    init(model: AppModel) {
        self.model = model
        super.init()
        NotificationCenter.default.addObserver(
            forName: .termPetVisibilityChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.model.isPetHidden {
                    self.window?.orderOut(nil)
                } else {
                    self.showWindow()
                }
            }
        }
        NotificationCenter.default.addObserver(
            forName: .termPetTogglePanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.showPanel()
            }
        }
    }

    func showWindow() {
        if window == nil {
            let size = min(max(CGFloat(model.settings.petSize), 150), 220)
            let frame = model.restoreWindowFrame(defaultSize: size)
            let petWindow = NSWindow(
                contentRect: frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            petWindow.isOpaque = false
            petWindow.backgroundColor = .clear
            petWindow.hasShadow = false
            petWindow.level = .floating
            petWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            petWindow.isMovableByWindowBackground = true
            petWindow.ignoresMouseEvents = false
            petWindow.contentView = NSHostingView(rootView: PetView(model: model))
            window = petWindow
            startFollowingTerminal()
        }
        window?.orderFrontRegardless()
        refreshPosition()
    }

    func setHidden(_ hidden: Bool) {
        if hidden {
            window?.orderOut(nil)
        } else {
            showWindow()
        }
    }

    private func showPanel() {
        if let infoPanel {
            infoPanel.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate()
            return
        }

        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "TermPet"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = FloatingPanelLifecyclePolicy.appHosted.releaseWhenClosed
        panel.delegate = self
        panel.contentView = NSHostingView(
            rootView: PetInfoPanel(model: model) { [weak panel] in
                panel?.close()
            }
        )

        if let petFrame = window?.frame, let screen = window?.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            let ps = panel.frame.size
            var x = petFrame.maxX + 16
            var y = petFrame.midY - ps.height / 2
            if x + ps.width > visible.maxX { x = petFrame.minX - ps.width - 16 }
            if x < visible.minX { x = petFrame.midX - ps.width / 2 }
            if y + ps.height > visible.maxY { y = visible.maxY - ps.height - 8 }
            if y < visible.minY + 4 { y = visible.minY + 4 }
            x = min(max(x, visible.minX + 4), visible.maxX - ps.width - 4)
            y = min(max(y, visible.minY + 4), visible.maxY - ps.height - 4)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            panel.center()
        }

        panel.makeKeyAndOrderFront(nil)
        infoPanel = panel
        model.isInfoPanelVisible = true
        NSApplication.shared.activate()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === infoPanel
        else { return }

        closingWindow.delegate = nil
        closingWindow.contentView = nil
        infoPanel = nil
        model.dismissInfoPanel()
    }

    private func startFollowingTerminal() {
        followTimer?.cancel()
        let queue = DispatchQueue.main
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 0.05)
        timer.setEventHandler { [weak self] in
            self?.refreshPosition()
        }
        timer.resume()
        followTimer = timer
    }

    private func refreshPosition() {
        guard let window else { return }

        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let frontmostIsTerminal = TerminalAppMatcher.isTerminal(
            bundleIdentifier: frontmostApplication?.bundleIdentifier,
            localizedName: frontmostApplication?.localizedName
        )
        model.setTerminalActive(frontmostIsTerminal)

        guard model.shouldRenderPet(frontmostIsTerminal: frontmostIsTerminal) else {
            window.orderOut(nil)
            return
        }

        if !window.isVisible {
            window.orderFrontRegardless()
        }

        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(mouse) })
                ?? NSScreen.main
        else { return }

        let visibleFrame = screen.visibleFrame
        let petSize = window.frame.size
        let cur = window.frame.origin

        let rMinX = visibleFrame.midX
        let rMinY = visibleFrame.minY
        let rW = visibleFrame.maxX - rMinX
        let rH = visibleFrame.maxY - rMinY
        let rMaxX = rMinX + rW
        let rMaxY = rMinY + rH
        let mx: CGFloat = petSize.width * 0.6
        let my: CGFloat = petSize.height * 0.3

        let tx = (mouse.x - visibleFrame.minX) / visibleFrame.width
        let ty = (mouse.y - visibleFrame.minY) / visibleFrame.height
        let tx2 = rMinX + (tx * 0.5 + 0.5) * rW - petSize.width / 2
        let ty2 = rMinY + (ty * 0.5 + 0.5) * rH - petSize.height / 2
        let cx = min(max(tx2, rMinX + mx), rMaxX - mx - petSize.width)
        let cy = min(max(ty2, rMinY + my), rMaxY - my - petSize.height)

        let s: CGFloat = 0.08
        let nx = cur.x + (cx - cur.x) * s
        let ny = cur.y + (cy - cur.y) * s

        window.setFrame(NSRect(x: nx, y: ny, width: petSize.width, height: petSize.height), display: true, animate: false)
        model.updateWindowFrame(window.frame)
        model.updateGaze(windowFrame: window.frame)
    }
}
