import Foundation

public struct FloatingPanelLifecyclePolicy: Equatable, Sendable {
    public let releaseWhenClosed: Bool
    public let retainWhileOpen: Bool

    public init(releaseWhenClosed: Bool, retainWhileOpen: Bool) {
        self.releaseWhenClosed = releaseWhenClosed
        self.retainWhileOpen = retainWhileOpen
    }

    public static let appHosted = FloatingPanelLifecyclePolicy(
        releaseWhenClosed: false,
        retainWhileOpen: true
    )
}
