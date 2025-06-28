import Foundation

public protocol AuthService: Sendable {
    func signIn(with result: ProviderAuthResult) async throws -> AuthResponse
    func signOut(token: String) async throws
    func refreshSession(refreshToken: String) async throws -> AuthResponse
    func getUserProfile(accessToken: String) async throws -> User
    func deleteAccount(accessToken: String) async throws
}