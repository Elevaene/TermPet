import Foundation
import TermPetCore

struct TestFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw TestFailure(message: message)
    }
}

func testPrivacyFilterRedactsCommonSecrets() throws {
    let raw = "curl -H 'Authorization: Bearer abc.def' https://api.example.test?token=tok_123 password=hunter2 OPENAI_API_KEY=sk-live-1234567890abcdef"

    let filtered = PrivacyFilter.redact(raw)

    try expect(filtered.contains("Authorization: Bearer [REDACTED]"), "bearer token should be redacted")
    try expect(filtered.contains("token=[REDACTED]"), "token query should be redacted")
    try expect(filtered.contains("password=[REDACTED]"), "password should be redacted")
    try expect(filtered.contains("OPENAI_API_KEY=[REDACTED]"), "API key assignment should be redacted")
    try expect(!filtered.contains("hunter2"), "raw password should not remain")
    try expect(!filtered.contains("sk-live-1234567890abcdef"), "raw API key should not remain")
}

func testTerminalEventsDecodeStartedAndFinishedJsonLines() throws {
    let startedJSON = #"{"type":"command_started","command":"sleep 1","startedAt":"2026-07-02T12:00:00Z"}"#
    let finishedJSON = #"{"type":"command_finished","command":"false","exitCode":1,"durationMs":42,"startedAt":"2026-07-02T12:00:00Z","finishedAt":"2026-07-02T12:00:01Z"}"#

    let started = try TerminalEvent(jsonLine: startedJSON)
    let finished = try TerminalEvent(jsonLine: finishedJSON)

    try expect(started.type == .commandStarted, "started event type")
    try expect(started.command == "sleep 1", "started command")
    try expect(started.exitCode == nil, "started exit code should be nil")
    try expect(finished.type == .commandFinished, "finished event type")
    try expect(finished.command == "false", "finished command")
    try expect(finished.exitCode == 1, "finished exit code")
    try expect(finished.durationMs == 42, "finished duration")
}

func testRepeatedFailuresWarnAfterThreeIdenticalCommands() throws {
    let responder = RuleBasedResponder()
    let brain = PetBrain(responder: responder)
    let first = TerminalEvent.finished(command: "npm test", exitCode: 1, durationMs: 1000)
    let second = TerminalEvent.finished(command: "npm test", exitCode: 1, durationMs: 1200)
    let third = TerminalEvent.finished(command: "npm test", exitCode: 1, durationMs: 1400)

    _ = brain.handle(first, settings: .init(personality: .technical))
    _ = brain.handle(second, settings: .init(personality: .technical))
    let response = brain.handle(third, settings: .init(personality: .technical))

    try expect(response.state == .shocked, "third repeated failure should shock pet")
    try expect(!response.message.isEmpty, "repeated failure should produce a message")
    try expect(response.isUrgent, "repeated failure should be urgent")
}

func testPersonalitiesProduceDifferentFailureTone() throws {
    let event = TerminalEvent.finished(command: "make deploy", exitCode: 2, durationMs: 500)
    let responder = RuleBasedResponder()

    // Run multiple times — random pools can collide rarely, but should diverge over samples
    var gentleSamples = Set<String>()
    var sarcasticSamples = Set<String>()
    var technicalSamples = Set<String>()
    for _ in 0..<20 {
        gentleSamples.insert(responder.respond(to: event, context: .init(personality: .gentle, repeatedFailureCount: 1)).message)
        sarcasticSamples.insert(responder.respond(to: event, context: .init(personality: .sarcastic, repeatedFailureCount: 1)).message)
        technicalSamples.insert(responder.respond(to: event, context: .init(personality: .technical, repeatedFailureCount: 1)).message)
    }

    // Each personality pool has 5 messages; after 20 tries we should see most of them
    try expect(gentleSamples.count >= 3, "gentle should produce multiple variants")
    try expect(sarcasticSamples.count >= 3, "sarcastic should produce multiple variants")
    try expect(technicalSamples.count >= 3, "technical should produce multiple variants")

    // Gentle pool should NOT contain sarcastic markers
    let sarcasticMarkers = ["炸了", "退场", "又双叒叕", "不那么乖", "爆炸"]
    for msg in gentleSamples {
        for marker in sarcasticMarkers {
            try expect(!msg.contains(marker), "gentle should not contain '\(marker)'")
        }
    }

    // Sarcastic pool should NOT contain gentle markers
    let gentleMarkers = ["没关系", "不要紧", "小小挫折", "不要紧"]
    for msg in sarcasticSamples {
        for marker in gentleMarkers {
            try expect(!msg.contains(marker), "sarcastic should not contain '\(marker)'")
        }
    }
}

func testDoNotDisturbSuppressesOrdinaryMessagesButKeepsState() throws {
    let brain = PetBrain(responder: RuleBasedResponder())
    let event = TerminalEvent.finished(command: "true", exitCode: 0, durationMs: 12)

    let response = brain.handle(event, settings: .init(doNotDisturb: true))

    try expect(response.state == .happy, "DND should keep state")
    try expect(response.message.isEmpty, "DND should suppress ordinary message")
}

func testSystemSnapshotProducesThresholdWarnings() throws {
    let snapshot = SystemSnapshot(
        cpuUsage: 0.91,
        memoryPressure: .high,
        diskFreeFraction: 0.08,
        batteryLevel: 0.18,
        isCharging: false
    )

    let warnings = SystemMonitorLogic.warnings(for: snapshot)

    try expect(warnings.contains(.highCPU), "high CPU warning")
    try expect(warnings.contains(.highMemoryPressure), "high memory warning")
    try expect(warnings.contains(.lowDiskSpace), "low disk warning")
    try expect(warnings.contains(.lowBattery), "low battery warning")
}

func testResponderFactoryFallsBackWhenAIIsNotConfigured() throws {
    let settings = TermPetSettings(aiProvider: .openAICompatible, apiBaseURL: "", apiKey: "")

    let responder = ResponderFactory.makeResponder(settings: settings)
    let response = responder.respond(
        to: .finished(command: "false", exitCode: 1, durationMs: 10),
        context: .init(personality: .gentle, repeatedFailureCount: 1)
    )

    try expect(!response.message.isEmpty, "unconfigured AI should fall back")
}

func testSettingsPreserveCustomPetImagePath() throws {
    let settings = TermPetSettings(customPetImagePath: "/tmp/term-pet.png")
    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(TermPetSettings.self, from: data)

    try expect(decoded.customPetImagePath == "/tmp/term-pet.png", "custom pet image path should persist")
}

func testDefaultSettingsUseBundledPetImage() throws {
    let settings = TermPetSettings()

    try expect(settings.customPetImagePath == "__bundled__", "default pet should be bundled image")
}

func testTerminalAppMatcherRecognizesTerminalApps() throws {
    try expect(TerminalAppMatcher.isTerminal(bundleIdentifier: "com.apple.Terminal", localizedName: "Terminal"), "Apple Terminal should match")
    try expect(TerminalAppMatcher.isTerminal(bundleIdentifier: "com.mitchellh.ghostty", localizedName: "Ghostty"), "Ghostty should match")
    try expect(TerminalAppMatcher.isTerminal(bundleIdentifier: "com.googlecode.iterm2", localizedName: "iTerm2"), "iTerm2 should match")
}

func testTerminalAppMatcherRejectsNonTerminalApps() throws {
    try expect(!TerminalAppMatcher.isTerminal(bundleIdentifier: "com.apple.Safari", localizedName: "Safari"), "Safari should not match")
    try expect(!TerminalAppMatcher.isTerminal(bundleIdentifier: "com.openai.chat", localizedName: "Codex"), "Codex should not match")
}

func testReminderStoreFiresDueReminders() throws {
    let store = ReminderStore()
    let pastDate = Date().addingTimeInterval(-1)
    store.addReminder(message: "test", fireAt: pastDate)
    let fired = store.checkAndFire()
    try expect(fired.count == 1, "should fire one past reminder")
    try expect(fired.first?.message == "test", "should return correct reminder")
    try expect(store.activeCount() == 0, "fired reminders should not be active")
}

func testReminderStorePresetAddsCorrectDelay() throws {
    let store = ReminderStore()
    store.addPreset(.fiveMinutes)
    try expect(store.activeCount() == 1, "preset should add one active reminder")
    let reminder = store.reminders.first!
    let diff = reminder.fireAt.timeIntervalSince(Date()) - (5 * 60)
    try expect(abs(diff) < 1, "preset fire time should be ~5 minutes from now")
}

func testReminderStoreCustomReminderRespectsCustomSeconds() throws {
    let store = ReminderStore()
    store.addCustomReminder(text: "开会", seconds: 600)
    try expect(store.activeCount() == 1, "custom reminder should add one active")
    try expect(store.reminders.first!.message.contains("开会"), "custom message should be preserved")
}

func testMemoryPressureTitleIsAccessible() throws {
    try expect(MemoryPressure.normal.title == "正常", "normal title")
    try expect(MemoryPressure.warning.title == "偏高", "warning title")
    try expect(MemoryPressure.high.title == "高", "high title")
}

func testFloatingPanelLifecycleKeepsAppOwnedPanelAlive() throws {
    let policy = FloatingPanelLifecyclePolicy.appHosted

    try expect(!policy.releaseWhenClosed, "app-hosted floating panels should not release themselves on close")
    try expect(policy.retainWhileOpen, "app-hosted floating panels should be retained while open")
}

let tests: [(String, () throws -> Void)] = [
    ("privacy filter redacts common secrets", testPrivacyFilterRedactsCommonSecrets),
    ("terminal events decode JSON lines", testTerminalEventsDecodeStartedAndFinishedJsonLines),
    ("repeated failures warn after three identical commands", testRepeatedFailuresWarnAfterThreeIdenticalCommands),
    ("personalities produce different failure tone", testPersonalitiesProduceDifferentFailureTone),
    ("do not disturb suppresses ordinary messages but keeps state", testDoNotDisturbSuppressesOrdinaryMessagesButKeepsState),
    ("system snapshot produces threshold warnings", testSystemSnapshotProducesThresholdWarnings),
    ("responder factory falls back when AI is not configured", testResponderFactoryFallsBackWhenAIIsNotConfigured),
    ("settings preserve custom pet image path", testSettingsPreserveCustomPetImagePath),
    ("default settings use bundled pet image", testDefaultSettingsUseBundledPetImage),
    ("terminal app matcher recognizes terminal apps", testTerminalAppMatcherRecognizesTerminalApps),
    ("terminal app matcher rejects non-terminal apps", testTerminalAppMatcherRejectsNonTerminalApps),
    ("reminder store fires due reminders", testReminderStoreFiresDueReminders),
    ("reminder store preset adds correct delay", testReminderStorePresetAddsCorrectDelay),
    ("reminder store custom reminder respects custom seconds", testReminderStoreCustomReminderRespectsCustomSeconds),
    ("memory pressure title is accessible", testMemoryPressureTitleIsAccessible),
    ("floating panel lifecycle keeps app owned panel alive", testFloatingPanelLifecycleKeepsAppOwnedPanelAlive),
]

for (name, test) in tests {
    do {
        try test()
        print("PASS \(name)")
    } catch {
        print("FAIL \(name): \(error)")
        exit(1)
    }
}

print("All TermPet logic tests passed")
