import Foundation

public enum CodexUsageError: LocalizedError, Equatable, Sendable {
    case codexNotFound(path: String)
    case notSignedIn
    case protocolError(String)
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case .codexNotFound(let path):
            return "Codex app not found at \(path)"
        case .notSignedIn:
            return "Sign in to Codex with ChatGPT"
        case .protocolError(let message):
            return message
        case .unavailable(let message):
            return message
        }
    }

    public static func fromServerMessage(_ message: String) -> CodexUsageError {
        let normalized = message.lowercased()
        if normalized.contains("auth")
            || normalized.contains("not signed in")
            || normalized.contains("not logged in")
            || normalized.contains("authentication required")
            || normalized.contains("api key auth is not supported") {
            return .notSignedIn
        }
        return .protocolError(message)
    }
}
