import Foundation

public enum TerminalEventType: String, Codable, Sendable {
    case commandStarted = "command_started"
    case commandFinished = "command_finished"
}

public struct TerminalEvent: Codable, Equatable, Sendable {
    public var type: TerminalEventType
    public var command: String
    public var exitCode: Int?
    public var durationMs: Int?
    public var startedAt: Date?
    public var finishedAt: Date?

    public init(
        type: TerminalEventType,
        command: String,
        exitCode: Int? = nil,
        durationMs: Int? = nil,
        startedAt: Date? = nil,
        finishedAt: Date? = nil
    ) {
        self.type = type
        self.command = PrivacyFilter.redact(command)
        self.exitCode = exitCode
        self.durationMs = durationMs
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    public init(jsonLine: String) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = Data(jsonLine.utf8)
        let decoded = try decoder.decode(TerminalEvent.self, from: data)
        self.init(
            type: decoded.type,
            command: decoded.command,
            exitCode: decoded.exitCode,
            durationMs: decoded.durationMs,
            startedAt: decoded.startedAt,
            finishedAt: decoded.finishedAt
        )
    }

    public static func started(command: String, startedAt: Date = Date()) -> TerminalEvent {
        TerminalEvent(type: .commandStarted, command: command, startedAt: startedAt)
    }

    public static func finished(
        command: String,
        exitCode: Int,
        durationMs: Int,
        startedAt: Date? = nil,
        finishedAt: Date = Date()
    ) -> TerminalEvent {
        TerminalEvent(
            type: .commandFinished,
            command: command,
            exitCode: exitCode,
            durationMs: durationMs,
            startedAt: startedAt,
            finishedAt: finishedAt
        )
    }

    public var isSuccess: Bool {
        type == .commandFinished && exitCode == 0
    }

    public var isFailure: Bool {
        type == .commandFinished && (exitCode ?? 0) != 0
    }

    public var isLongRunning: Bool {
        (durationMs ?? 0) >= 30_000
    }
}
