import Foundation

enum AppPaths {
    static var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("TermPet", isDirectory: true)
    }

    static var eventLogURL: URL {
        applicationSupportDirectory.appendingPathComponent("events.jsonl")
    }

    static var runtimeLogURL: URL {
        applicationSupportDirectory.appendingPathComponent("runtime.log")
    }

    static var customPetImageURL: URL {
        applicationSupportDirectory.appendingPathComponent("custom-pet-image.png")
    }

    static func ensureApplicationSupportDirectory() {
        try? FileManager.default.createDirectory(
            at: applicationSupportDirectory,
            withIntermediateDirectories: true
        )
    }
}
