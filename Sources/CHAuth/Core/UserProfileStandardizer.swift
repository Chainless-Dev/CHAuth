import Foundation

public protocol UserProfileStandardizer: Sendable {
    func standardize(from provider: ProviderAuthResult, and service: AuthResponse) -> User
}