import AppKit
import Combine
import Foundation
import TermPetCore
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published var petState: PetState = .idle
    @Published var message: String = "双击收起，按 ⌥⌘P 恢复"
    @Published var settings: TermPetSettings
    @Published var isPetHidden = false
    @Published var isTerminalActive = false
    @Published var recentEvents: [TerminalEvent] = []
    @Published var latestSystemSnapshot: SystemSnapshot?
    @Published var gazeOffset: CGSize = .zero
    @Published var isInfoPanelVisible = false
    @Published var mouseDirection: PetMouseDirection = .none

    let eventLogURL: URL
    let reminderStore = ReminderStore()
    private let settingsStore: SettingsStore
    private var brain: PetBrain
    private var eventReader: TerminalEventLogReader
    private var eventTimer: Timer?
    private var idleTimer: Timer?
    private var systemTimer: Timer?
    private var reminderTimer: Timer?
    private var lastActivity = Date()
    private var lastSpokenAt = Date.distantPast
    private var idleNotificationFired = false
    private var messageDismissTask: Task<Void, Never>?

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        let loadedSettings = settingsStore.loadSettings()
        let logURL = AppPaths.eventLogURL
        self.settings = loadedSettings
        self.eventLogURL = logURL
        let responder = ResponderFactory.makeResponder(settings: loadedSettings)
        self.brain = PetBrain(responder: responder)
        self.eventReader = TerminalEventLogReader(url: logURL)
    }

    func start() {
        AppPaths.ensureApplicationSupportDirectory()
        eventTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollTerminalEvents()
            }
        }
        idleTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluateIdleState()
            }
        }
        systemTimer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollSystemSnapshot()
            }
        }
        reminderTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollReminders()
            }
        }
        requestNotificationPermission()
    }

    func stop() {
        eventTimer?.invalidate()
        idleTimer?.invalidate()
        systemTimer?.invalidate()
        reminderTimer?.invalidate()
    }

    func updateSettings(_ nextSettings: TermPetSettings) {
        settingsStore.saveSettings(nextSettings)
        let savedSettings = settingsStore.loadSettings()
        settings = savedSettings
        brain = PetBrain(responder: ResponderFactory.makeResponder(settings: savedSettings))
    }

    func setPetHidden(_ hidden: Bool) {
        isPetHidden = hidden
    }

    func setTerminalActive(_ active: Bool) {
        isTerminalActive = active
    }

    func hideFromPetDoubleClick() {
        setPetHidden(true)
        NotificationCenter.default.post(name: .termPetVisibilityChanged, object: nil)
    }

    func togglePetVisibilityFromShortcut() {
        setPetHidden(!isPetHidden)
        NotificationCenter.default.post(name: .termPetVisibilityChanged, object: nil)
    }

    func toggleListeningPaused() {
        var next = settings
        next.isListeningPaused.toggle()
        updateSettings(next)
    }

    func updateWindowFrame(_ frame: NSRect) {
        settingsStore.saveWindowFrame(frame)
    }

    func importCustomPetImage(from sourceURL: URL) throws {
        AppPaths.ensureApplicationSupportDirectory()
        let destination = AppPaths.customPetImageURL
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)

        var next = settings
        next.customPetImagePath = destination.path
        updateSettings(next)
    }

    func useDefaultPetImage() {
        var next = settings
        next.customPetImagePath = "__bundled__"
        updateSettings(next)
    }

    func shouldRenderPet(frontmostIsTerminal: Bool) -> Bool {
        !isPetHidden && frontmostIsTerminal
    }

    func restoreWindowFrame(defaultSize: CGFloat) -> NSRect {
        let contentSize = NSSize(
            width: max(defaultSize + 92, 280),
            height: max(defaultSize + 92, 272)
        )
        return settingsStore.loadWindowFrame(defaultContentSize: contentSize)
    }

    func handleClick() {
        // Triggers panel toggle via notification so PetWindowController handles it
        NotificationCenter.default.post(name: .termPetTogglePanel, object: nil)
    }

    func dismissInfoPanel() {
        isInfoPanelVisible = false
    }

    func updateGaze(windowFrame: NSRect) {
        let mouse = NSEvent.mouseLocation
        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        let dx = mouse.x - center.x
        let dy = mouse.y - center.y
        let distance = max(sqrt(dx * dx + dy * dy), 1)
        gazeOffset = CGSize(width: dx / distance * 5, height: dy / distance * 4)
        updateMouseDirection(dx: dx, dy: dy, distance: distance)
    }

    private func updateMouseDirection(dx: CGFloat, dy: CGFloat, distance: CGFloat) {
        let absDx = abs(dx)
        let absDy = abs(dy)
        if distance < 50 {
            mouseDirection = .near
        } else if absDx > absDy && absDx > 20 {
            mouseDirection = dx > 0 ? .right : .left
        } else if absDy > absDx && absDy > 20 {
            mouseDirection = dy > 0 ? .up : .down
        } else {
            mouseDirection = .none
        }
    }

    private func pollTerminalEvents() {
        guard !settings.isListeningPaused else { return }

        do {
            let events = try eventReader.readNewEvents()
            for event in events {
                recentEvents.insert(event, at: 0)
                recentEvents = Array(recentEvents.prefix(10))
                lastActivity = Date()

                if event.type == .commandStarted {
                    petState = .working
                    message = "工作中..."
                    continue
                }

                let response = brain.handle(event, settings: settings)
                speak(response.message, state: response.state, force: response.isUrgent)

                if event.isLongRunning && event.isSuccess {
                    speak("等到了，命令跑完了。", state: .happy, force: false)
                }
            }
        } catch {
            speak("事件读取失败：\(error.localizedDescription)", state: .shocked, force: true)
        }
    }

    private func evaluateIdleState() {
        let idleSeconds = Date().timeIntervalSince(lastActivity)
        if idleSeconds >= 3600 {
            speak("休息一下也很合理。", state: .sleeping, force: false)
            if !idleNotificationFired {
                deliverNotification(title: "TermPet", body: "你已经一个小时没有操作了，休息一下吧。")
                idleNotificationFired = true
            }
        } else if idleSeconds >= 1200 {
            petState = .sleeping
            if message.isEmpty {
                message = "zzZ"
            }
        }
        if idleSeconds < 1200 {
            idleNotificationFired = false
        }
    }

    private func pollReminders() {
        let fired = reminderStore.checkAndFire()
        for reminder in fired {
            speak(reminder.message, state: .happy, force: true)
            deliverNotification(title: "TermPet 提醒", body: reminder.message)
        }
    }

    private func requestNotificationPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func deliverNotification(title: String, body: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func pollSystemSnapshot() {
        let snapshot = SystemSampler.sample()
        latestSystemSnapshot = snapshot
        let warnings = SystemMonitorLogic.warnings(for: snapshot)
        guard let warning = warnings.first else { return }
        speak(warning.message, state: .shocked, force: false)
    }

    private func speak(_ nextMessage: String, state: PetState, force: Bool) {
        petState = state
        guard !nextMessage.isEmpty else {
            message = ""
            return
        }

        if settings.doNotDisturb && !force {
            return
        }

        let now = Date()
        guard force || now.timeIntervalSince(lastSpokenAt) >= settings.speechFrequencySeconds else {
            return
        }

        message = nextMessage
        lastSpokenAt = now

        messageDismissTask?.cancel()
        messageDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            message = ""
            if petState != .sleeping {
                petState = .idle
            }
        }
    }
}

private extension MemoryPressure {
    var title: String {
        switch self {
        case .normal: "正常"
        case .warning: "偏高"
        case .high: "高"
        }
    }
}
