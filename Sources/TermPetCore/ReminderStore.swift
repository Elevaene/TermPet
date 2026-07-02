import Foundation

public struct Reminder: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var message: String
    public var fireAt: Date
    public var isFired: Bool

    public init(id: UUID = UUID(), message: String, fireAt: Date, isFired: Bool = false) {
        self.id = id
        self.message = message
        self.fireAt = fireAt
        self.isFired = isFired
    }

    public var remainingSeconds: TimeInterval {
        max(fireAt.timeIntervalSinceNow, 0)
    }

    public var isDue: Bool {
        !isFired && fireAt.timeIntervalSinceNow <= 0
    }
}

public enum ReminderPreset: CaseIterable, Sendable {
    case fiveMinutes
    case fifteenMinutes
    case thirtyMinutes
    case oneHour

    public var title: String {
        switch self {
        case .fiveMinutes: "5 分钟"
        case .fifteenMinutes: "15 分钟"
        case .thirtyMinutes: "30 分钟"
        case .oneHour: "1 小时"
        }
    }

    public var seconds: TimeInterval {
        switch self {
        case .fiveMinutes: 5 * 60
        case .fifteenMinutes: 15 * 60
        case .thirtyMinutes: 30 * 60
        case .oneHour: 60 * 60
        }
    }
}

public final class ReminderStore: ObservableObject {
    @Published public private(set) var reminders: [Reminder] = []
    @Published public var notificationMessage: String = ""

    public init() {
        reminders = []
    }

    public func addReminder(message: String, fireAt: Date) {
        let reminder = Reminder(message: message, fireAt: fireAt)
        reminders.append(reminder)
        reminders.sort { $0.fireAt < $1.fireAt }
    }

    public func addPreset(_ preset: ReminderPreset) {
        let fireAt = Date().addingTimeInterval(preset.seconds)
        addReminder(message: "⏰ \(preset.title)到了，该休息一下啦。", fireAt: fireAt)
    }

    public func addCustomReminder(text: String, seconds: TimeInterval) {
        let fireAt = Date().addingTimeInterval(seconds)
        addReminder(message: "⏰ \(text)", fireAt: fireAt)
    }

    public func removeReminder(id: UUID) {
        reminders.removeAll { $0.id == id }
    }

    public func checkAndFire() -> [Reminder] {
        let due = reminders.filter { $0.isDue }
        for var reminder in due {
            reminder.isFired = true
            if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                reminders[index] = reminder
            }
        }
        for reminder in due {
            notificationMessage = reminder.message
        }
        return due
    }

    public func activeCount() -> Int {
        reminders.filter { !$0.isFired }.count
    }
}
