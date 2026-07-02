import AppKit
import Foundation
import TermPetCore

final class SettingsStore {
    private let defaults: UserDefaults
    private let settingsKey = "TermPet.settings"
    private let windowFrameKey = "TermPet.windowFrame"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSettings() -> TermPetSettings {
        guard let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(TermPetSettings.self, from: data)
        else {
            return TermPetSettings()
        }
        return normalized(settings)
    }

    func saveSettings(_ settings: TermPetSettings) {
        if let data = try? JSONEncoder().encode(normalized(settings)) {
            defaults.set(data, forKey: settingsKey)
        }
    }

    func saveWindowFrame(_ frame: NSRect) {
        defaults.set(NSStringFromRect(frame), forKey: windowFrameKey)
    }

    func loadWindowFrame(defaultContentSize: NSSize) -> NSRect {
        guard let value = defaults.string(forKey: windowFrameKey) else {
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
            return clampToVisibleScreen(NSRect(
                x: screenFrame.maxX - defaultContentSize.width - 40,
                y: screenFrame.minY + 80,
                width: defaultContentSize.width,
                height: defaultContentSize.height
            ))
        }

        var frame = NSRectFromString(value)
        if frame.width > 40 && frame.height > 40 {
            frame.size = defaultContentSize
            return clampToVisibleScreen(frame)
        }

        return clampToVisibleScreen(NSRect(
            x: 80,
            y: 80,
            width: defaultContentSize.width,
            height: defaultContentSize.height
        ))
    }

    private func normalized(_ settings: TermPetSettings) -> TermPetSettings {
        var normalized = settings
        if normalized.petSize > 240 {
            normalized.petSize = 180
        } else {
            normalized.petSize = min(max(normalized.petSize, 150), 220)
        }
        normalized.speechFrequencySeconds = min(max(normalized.speechFrequencySeconds, 5), 120)
        if normalized.customPetImagePath.isEmpty || normalized.customPetImagePath == "__vector__" {
            normalized.customPetImagePath = "__bundled__"
        }
        return normalized
    }

    private func clampToVisibleScreen(_ frame: NSRect) -> NSRect {
        let screenFrame = NSScreen.screens
            .map(\.visibleFrame)
            .first { $0.intersects(frame) }
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1280, height: 800)

        var clamped = frame
        clamped.size.width = min(clamped.width, screenFrame.width)
        clamped.size.height = min(clamped.height, screenFrame.height)
        clamped.origin.x = min(max(clamped.minX, screenFrame.minX), screenFrame.maxX - clamped.width)
        clamped.origin.y = min(max(clamped.minY, screenFrame.minY), screenFrame.maxY - clamped.height)
        return clamped
    }
}
