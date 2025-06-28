import Foundation

public protocol AuthCoordinator: Sendable {
    func signIn(with provider: AuthProviderType) async throws -> User
    func signOut() async throws
    func refreshSession() async throws -> User
    func handleProviderCallback(url: URL) async -> Bool
}