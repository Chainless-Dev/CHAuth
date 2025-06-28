import Foundation
@preconcurrency import KeychainAccess

public final class KeychainSessionManager: SessionManager {
    private let keychain: Keychain
    private let authService: AuthService
    
    private enum Keys {
        static let accessToken = "auth.access_token"
        static let refreshToken = "auth.refresh_token"
        static let expiresAt = "auth.expires_at"
        static let tokenType = "auth.token_type"
    }
    
    public init(authService: AuthService, service: String = "com.chainless.CHAuth") {
        self.authService = authService
        self.keychain = Keychain(service: service)
            .accessibility(.afterFirstUnlockThisDeviceOnly)
    }
    
    public var currentAccessToken: String? {
        get async {
            try? keychain.get(Keys.accessToken)
        }
    }
    
    public var currentRefreshToken: String? {
        get async {
            try? keychain.get(Keys.refreshToken)
        }
    }
    
    public var tokenExpiresAt: Date? {
        get async {
            guard let expiresAtString = try? keychain.get(Keys.expiresAt),
                  let timestamp = TimeInterval(expiresAtString) else {
                return nil
            }
            return Date(timeIntervalSince1970: timestamp)
        }
    }
    
    public func store(tokens: AuthTokens) async throws {
        try keychain.set(tokens.accessToken, key: Keys.accessToken)
        try keychain.set(tokens.refreshToken, key: Keys.refreshToken)
        try keychain.set(tokens.tokenType, key: Keys.tokenType)
        
        if let expiresAt = tokens.expiresAt {
            try keychain.set(String(expiresAt.timeIntervalSince1970), key: Keys.expiresAt)
        }
    }
    
    public func clearSession() async throws {
        try keychain.remove(Keys.accessToken)
        try keychain.remove(Keys.refreshToken)
        try keychain.remove(Keys.expiresAt)
        try keychain.remove(Keys.tokenType)
    }
    
    public func refreshTokens() async throws -> AuthTokens {
        guard let refreshToken = await currentRefreshToken else {
            throw AuthError.sessionExpired
        }
        
        let response = try await authService.refreshSession(refreshToken: refreshToken)
        
        let tokens = AuthTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: response.expiresAt,
            tokenType: response.tokenType
        )
        
        try await store(tokens: tokens)
        return tokens
    }
    
    public func isSessionValid() async -> Bool {
        guard await currentAccessToken != nil else {
            return false
        }
        
        if let expiresAt = await tokenExpiresAt {
            return expiresAt > Date().addingTimeInterval(60) // 1 minute buffer
        }
        
        return true
    }
}
