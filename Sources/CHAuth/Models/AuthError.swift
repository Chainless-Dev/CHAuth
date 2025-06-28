import Foundation

public enum AuthError: LocalizedError, Sendable {
    case configurationError(String)
    case providerError(AuthProviderType, Error)
    case serviceError(Error)
    case networkError(Error)
    case sessionExpired
    case cancelled
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .providerError(let provider, let error):
            return "Provider error (\(provider.rawValue)): \(error.localizedDescription)"
        case .serviceError(let error):
            return "Service error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .sessionExpired:
            return "Session has expired"
        case .cancelled:
            return "Authentication was cancelled"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .configurationError:
            return "Please check your authentication configuration."
        case .providerError:
            return "Please try signing in with a different provider."
        case .serviceError:
            return "Please check your network connection and try again."
        case .networkError:
            return "Please check your network connection and try again."
        case .sessionExpired:
            return "Please sign in again."
        case .cancelled:
            return "Please try signing in again."
        case .unknown:
            return "Please try again later."
        }
    }
}

extension AuthError: Equatable {
    public static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.configurationError(let lhsMessage), .configurationError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.providerError(let lhsProvider, _), .providerError(let rhsProvider, _)):
            return lhsProvider == rhsProvider
        case (.sessionExpired, .sessionExpired):
            return true
        case (.cancelled, .cancelled):
            return true
        default:
            return false
        }
    }
}