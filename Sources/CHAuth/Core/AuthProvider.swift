import Foundation

public protocol AuthProvider: Sendable {
    var providerType: AuthProviderType { get }
    var redirectScheme: String? { get }
    var requiredScopes: [String] { get }
    
    func authenticate() async throws -> ProviderAuthResult
    func handleCallback(url: URL) throws -> ProviderAuthResult?
    func refreshToken(_ refreshToken: String) async throws -> ProviderAuthResult
    func signOut() async throws
}