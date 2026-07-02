import Foundation

public final class PetBrain {
    private let responder: any PetResponder
    private var lastFailedCommand: String?
    private var repeatedFailureCount = 0

    public init(responder: any PetResponder) {
        self.responder = responder
    }

    public func handle(_ event: TerminalEvent, settings: TermPetSettings) -> PetResponse {
        if event.isFailure {
            if event.command == lastFailedCommand {
                repeatedFailureCount += 1
            } else {
                lastFailedCommand = event.command
                repeatedFailureCount = 1
            }
        } else if event.type == .commandFinished {
            lastFailedCommand = nil
            repeatedFailureCount = 0
        }

        var response = responder.respond(
            to: event,
            context: ResponderContext(
                personality: settings.personality,
                repeatedFailureCount: repeatedFailureCount
            )
        )

        if settings.doNotDisturb && !response.isUrgent {
            response.message = ""
        }

        return response
    }
}
