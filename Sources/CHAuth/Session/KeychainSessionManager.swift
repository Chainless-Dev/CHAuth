import Foundation
@preconcurrency import KeychainAccess
import CHLogger

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
        log.debug("SessionManager: Storing tokens in keychain")
        
        try keychain.set(tokens.accessToken, key: Keys.accessToken)
        try keychain.set(tokens.refreshToken, key: Keys.refreshToken)
        try keychain.set(tokens.tokenType, key: Keys.tokenType)
        
        if let expiresAt = tokens.expiresAt {
            try keychain.set(String(expiresAt.timeIntervalSince1970), key: Keys.expiresAt)
            log.debug("SessionManager: Tokens stored with expiration: \(expiresAt)")
        } else {
            log.debug("SessionManager: Tokens stored without expiration")
        }
    }
    
    public func clearSession() async throws {
        log.info("SessionManager: Clearing session from keychain")
        
        try keychain.remove(Keys.accessToken)
        try keychain.remove(Keys.refreshToken)
        try keychain.remove(Keys.expiresAt)
        try keychain.remove(Keys.tokenType)
        
        log.debug("SessionManager: Session cleared successfully")
    }
    
    public func refreshTokens() async throws -> AuthTokens {
        log.debug("SessionManager: Starting token refresh")
        
        guard let refreshToken = await currentRefreshToken else {
            log.error("SessionManager: No refresh token available for refresh")
            throw AuthError.sessionExpired
        }
        
        log.debug("SessionManager: Calling auth service to refresh tokens")
        let response = try await authService.refreshSession(refreshToken: refreshToken)
        
        let tokens = AuthTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: response.expiresAt,
            tokenType: response.tokenType
        )
        
        try await store(tokens: tokens)
        log.info("SessionManager: Token refresh completed successfully")
        return tokens
    }
    
    public func isSessionValid() async -> Bool {
        log.debug("SessionManager: Checking session validity")
        
        guard await currentAccessToken != nil else {
            log.debug("SessionManager: No access token found, session invalid")
            return false
        }
        
        if let expiresAt = await tokenExpiresAt {
            let isValid = expiresAt > Date().addingTimeInterval(60) // 1 minute buffer
            log.debug("SessionManager: Token expires at \(expiresAt), valid: \(isValid)")
            
            // If token is expired, attempt silent refresh
            if !isValid {
                log.info("SessionManager: Token expired, attempting silent refresh")
                do {
                    _ = try await refreshTokens()
                    log.info("SessionManager: Silent refresh successful")
                    return true
                } catch {
                    log.error("SessionManager: Silent refresh failed: \(error.localizedDescription)")
                    return false
                }
            }
            
            return isValid
        }
        
        log.debug("SessionManager: No expiration date found, assuming valid")
        return true
    }
}
