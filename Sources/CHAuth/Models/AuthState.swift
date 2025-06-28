import Foundation

public enum AuthState: Sendable {
    case unauthenticated
    case authenticating(AuthProviderType)
    case authenticated(User)
    case refreshing
    case error(AuthError)
}

extension AuthState: Equatable {
    public static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.unauthenticated, .unauthenticated):
            return true
        case (.authenticating(let lhsProvider), .authenticating(let rhsProvider)):
            return lhsProvider == rhsProvider
        case (.authenticated(let lhsUser), .authenticated(let rhsUser)):
            return lhsUser.id == rhsUser.id
        case (.refreshing, .refreshing):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}