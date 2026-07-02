import Foundation

public enum TerminalAppMatcher {
    private static let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
        "dev.warp.Warp",
        "com.github.wez.wezterm",
        "org.alacritty",
        "net.kovidgoyal.kitty"
    ]

    private static let terminalNames: Set<String> = [
        "terminal",
        "iterm",
        "iterm2",
        "ghostty",
        "warp",
        "wezterm",
        "alacritty",
        "kitty"
    ]

    public static func isTerminal(bundleIdentifier: String?, localizedName: String?) -> Bool {
        if let bundleIdentifier, terminalBundleIDs.contains(bundleIdentifier) {
            return true
        }

        guard let localizedName else {
            return false
        }

        let normalizedName = localizedName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return terminalNames.contains(normalizedName)
    }
}
