import Darwin
import Foundation

enum RuntimeLogRedirector {
    static func installUnlessDebugEnabled() {
        guard ProcessInfo.processInfo.environment["TERMPET_DEBUG_LOGS"] != "1" else {
            return
        }

        AppPaths.ensureApplicationSupportDirectory()
        freopen(AppPaths.runtimeLogURL.path, "a", stderr)
    }
}
