import Foundation

public enum PrivacyFilter {
    private static let replacements: [(pattern: String, replacement: String)] = [
        (#"(?i)(Authorization\s*:\s*Bearer\s+)[^'"\s]+"#, "$1[REDACTED]"),
        (#"(?i)\b([A-Z0-9_]*(?:TOKEN|PASSWORD|PASSWD|SECRET|API_KEY|APIKEY|KEY)|token|password|passwd|secret|api[_-]?key)=([^&\s'";]+)"#, "$1=[REDACTED]"),
        (#"(?i)\b(sk-[A-Za-z0-9_\-]{12,})\b"#, "[REDACTED]")
    ]

    public static func redact(_ value: String) -> String {
        replacements.reduce(value) { current, rule in
            guard let regex = try? NSRegularExpression(pattern: rule.pattern) else {
                return current
            }
            let range = NSRange(current.startIndex..<current.endIndex, in: current)
            return regex.stringByReplacingMatches(
                in: current,
                options: [],
                range: range,
                withTemplate: rule.replacement
            )
        }
    }
}
