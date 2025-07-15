import Testing
import Foundation
@testable import CHAuth

@Test("User model creation and display name")
func testUserModel() async throws {
    let user = User(
        id: "123",
        email: "test@example.com",
        fullName: "John Doe",
        givenName: "John",
        familyName: "Doe",
        avatarURL: URL(string: "https://example.com/avatar.jpg"),
        provider: .apple,
        createdAt: Date(),
        lastSignInAt: Date()
    )
    
    #expect(user.id == "123")
    #expect(user.email == "test@example.com")
    #expect(user.displayName == "John Doe")
    #expect(user.provider == .apple)
}

@Test("User display name fallback")
func testUserDisplayNameFallback() async throws {
    let userWithEmail = User(
        id: "123",
        email: "test@example.com",
        fullName: nil,
        provider: .google,
        createdAt: Date(),
        lastSignInAt: Date()
    )
    
    #expect(userWithEmail.displayName == "test@example.com")
    
    let userUnknown = User(
        id: "123",
        email: nil,
        fullName: nil,
        provider: .apple,
        createdAt: Date(),
        lastSignInAt: Date()
    )
    
    #expect(userUnknown.displayName == "Unknown User")
}

@Test("AuthState equality")
func testAuthStateEquality() async throws {
    let user = User(
        id: "123",
        email: "test@example.com",
        fullName: "Test User",
        provider: .apple,
        createdAt: Date(),
        lastSignInAt: Date()
    )
    
    let state1 = AuthState.authenticated(user)
    let state2 = AuthState.authenticated(user)
    let state3 = AuthState.unauthenticated
    
    #expect(state1 == state2)
    #expect(state1 != state3)
    #expect(AuthState.unauthenticated == AuthState.unauthenticated)
    #expect(AuthState.authenticating(.apple) == AuthState.authenticating(.apple))
    #expect(AuthState.authenticating(.apple) != AuthState.authenticating(.google))
}

@Test("AuthError descriptions")
func testAuthErrorDescriptions() async throws {
    let configError = AuthError.configurationError("Missing client ID")
    #expect(configError.errorDescription?.contains("Missing client ID") == true)
    
    let providerError = AuthError.providerError(.apple, NSError(domain: "Test", code: 1))
    #expect(providerError.errorDescription?.contains("apple") == true)
    
    let sessionExpired = AuthError.sessionExpired
    #expect(sessionExpired.errorDescription == "Session has expired")
    #expect(sessionExpired.recoverySuggestion == "Please sign in again.")
}

@Test("AuthProviderType properties")
func testAuthProviderType() async throws {
    #expect(AuthProviderType.apple.displayName == "Apple")
    #expect(AuthProviderType.google.displayName == "Google")
    
    #expect(AuthProviderType.apple.rawValue == "apple")
    #expect(AuthProviderType.google.rawValue == "google")
}

@Test("ProviderAuthResult creation")
func testProviderAuthResult() async throws {
    let result = ProviderAuthResult(
        accessToken: "access_token",
        refreshToken: "refresh_token",
        idToken: "id_token",
        expiresAt: Date(),
        scope: "openid profile",
        userInfo: ["email": AnySendableValue("test@example.com")],
        provider: .google
    )
    
    #expect(result.accessToken == "access_token")
    #expect(result.refreshToken == "refresh_token")
    #expect(result.provider == .google)
    #expect(result.userInfo["email"]?.stringValue == "test@example.com")
}

@Test("AuthTokens creation")
func testAuthTokens() async throws {
    let tokens = AuthTokens(
        accessToken: "access",
        refreshToken: "refresh",
        expiresAt: Date(),
        tokenType: "Bearer"
    )
    
    #expect(tokens.accessToken == "access")
    #expect(tokens.refreshToken == "refresh")
    #expect(tokens.tokenType == "Bearer")
}

@Test("CHAuthConfiguration creation")
func testCHAuthConfiguration() async throws {
    let mockService = MockAuthService()
    
    let config = await MainActor.run {
        let mockProvider = MockAuthProvider()
        return CHAuthConfiguration(
            service: mockService,
            providers: [mockProvider],
            options: CHAuthOptions(automaticTokenRefresh: false)
        )
    }
    
    #expect(config.providers.count == 1)
    #expect(config.options.automaticTokenRefresh == false)
    #expect(config.options.sessionPersistence == true) // default
}

// MARK: - Mock Classes for Testing

final class MockAuthService: AuthService, @unchecked Sendable {
    func signIn(with result: ProviderAuthResult) async throws -> AuthResponse {
        let serviceUser = ServiceUser(
            id: "test_id",
            email: "test@example.com",
            createdAt: Date(),
            lastSignInAt: Date()
        )
        
        return AuthResponse(
            accessToken: "mock_access_token",
            refreshToken: "mock_refresh_token",
            user: serviceUser,
            expiresAt: Date().addingTimeInterval(3600)
        )
    }
    
    func signOut(token: String) async throws {
        // Mock implementation
    }
    
    func refreshSession(refreshToken: String) async throws -> AuthResponse {
        throw AuthError.sessionExpired
    }
    
    func getUserProfile(accessToken: String) async throws -> User {
        return User(
            id: "test_id",
            email: "test@example.com",
            fullName: "Test User",
            provider: .apple,
            createdAt: Date(),
            lastSignInAt: Date()
        )
    }
    
    func deleteAccount(accessToken: String) async throws {
        // Mock implementation
    }
}

@MainActor
final class MockAuthProvider: AuthProvider {
    let providerType: AuthProviderType = .apple
    let redirectScheme: String? = nil
    let requiredScopes: [String] = []
    
    func authenticate() async throws -> ProviderAuthResult {
        return ProviderAuthResult(
            accessToken: "mock_token",
            provider: .apple
        )
    }
    
    func handleCallback(url: URL) throws -> ProviderAuthResult? {
        return nil
    }
    
    func refreshToken(_ refreshToken: String) async throws -> ProviderAuthResult {
        throw AuthError.providerError(.apple, NSError(domain: "Mock", code: 1))
    }
    
    func signOut() async throws {
        // Mock implementation
    }
}
