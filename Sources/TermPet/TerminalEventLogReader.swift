import Foundation
import TermPetCore

final class TerminalEventLogReader {
    private let url: URL
    private var offset: UInt64 = 0

    init(url: URL) {
        self.url = url
    }

    func readNewEvents() throws -> [TerminalEvent] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attributes[.size] as? UInt64 ?? 0
        if size < offset {
            offset = 0
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: offset)
        let data = try handle.readToEnd() ?? Data()
        offset = try handle.offset()

        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            return []
        }

        return text
            .split(separator: "\n")
            .compactMap { try? TerminalEvent(jsonLine: String($0)) }
    }
}
