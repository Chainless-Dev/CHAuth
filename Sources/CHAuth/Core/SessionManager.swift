import Foundation

public protocol SessionManager: Sendable {
    var currentAccessToken: String? { get async }
    var currentRefreshToken: String? { get async }
    var tokenExpiresAt: Date? { get async }
    
    func store(tokens: AuthTokens) async throws
    func clearSession() async throws
    func refreshTokens() async throws -> AuthTokens
    func isSessionValid() async -> Bool
}