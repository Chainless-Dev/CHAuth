import Foundation
import CHLogger

public final class DefaultAuthCoordinator: AuthCoordinator {
    private let providers: [AuthProviderType: AuthProvider]
    private let authService: AuthService
    private let sessionManager: SessionManager
    private let userStandardizer: UserProfileStandardizer
    
    public init(
        providers: [AuthProviderType: AuthProvider],
        authService: AuthService,
        sessionManager: SessionManager,
        userStandardizer: UserProfileStandardizer
    ) {
        self.providers = providers
        self.authService = authService
        self.sessionManager = sessionManager
        self.userStandardizer = userStandardizer
    }
    
    public func signIn(with providerType: AuthProviderType) async throws -> User {
        log.info("Coordinator: Starting sign in with provider \(providerType.rawValue)")
        
        guard let provider = providers[providerType] else {
            log.error("Coordinator: Provider \(providerType.rawValue) not configured")
            throw AuthError.configurationError("Provider \(providerType.rawValue) not configured")
        }
        
        do {
            log.debug("Coordinator: Authenticating with provider")
            let providerResult = try await provider.authenticate()
            log.debug("Coordinator: Provider authentication successful, calling auth service")
            let serviceResponse = try await authService.signIn(with: providerResult)
            
            let tokens = AuthTokens(
                accessToken: serviceResponse.accessToken,
                refreshToken: serviceResponse.refreshToken,
                expiresAt: serviceResponse.expiresAt,
                tokenType: serviceResponse.tokenType
            )
            
            log.debug("Coordinator: Storing tokens in session manager")
            try await sessionManager.store(tokens: tokens)
            
            let user = userStandardizer.standardize(from: providerResult, and: serviceResponse)
            log.info("Coordinator: Sign in completed successfully for user \(user.id)")
            return user
        } catch {
            let finalError = (error as? AuthError) ?? AuthError.providerError(providerType, error)
            log.error("Coordinator: Sign in failed - \(finalError.localizedDescription)")
            throw finalError
        }
    }
    
    public func signOut() async throws {
        log.info("Coordinator: Starting sign out")
        
        if let accessToken = await sessionManager.currentAccessToken {
            log.debug("Coordinator: Access token found, calling auth service sign out")
            try await authService.signOut(token: accessToken)
        } else {
            log.debug("Coordinator: No access token found, skipping auth service sign out")
        }
        
        log.debug("Coordinator: Clearing session from session manager")
        try await sessionManager.clearSession()
        log.info("Coordinator: Sign out completed successfully")
    }
    
    public func refreshSession() async throws -> User {
        log.info("Coordinator: Starting session refresh")
        
        guard let refreshToken = await sessionManager.currentRefreshToken else {
            log.error("Coordinator: No refresh token available")
            throw AuthError.sessionExpired
        }
        
        do {
            log.debug("Coordinator: Calling auth service to refresh session")
            let serviceResponse = try await authService.refreshSession(refreshToken: refreshToken)
            
            let tokens = AuthTokens(
                accessToken: serviceResponse.accessToken,
                refreshToken: serviceResponse.refreshToken,
                expiresAt: serviceResponse.expiresAt,
                tokenType: serviceResponse.tokenType
            )
            
            log.debug("Coordinator: Storing refreshed tokens")
            try await sessionManager.store(tokens: tokens)
            
            // Create a dummy provider result for standardization
            let providerResult = ProviderAuthResult(
                accessToken: serviceResponse.accessToken,
                provider: serviceResponse.user.provider ?? .apple // Default fallback
            )
            
            let user = userStandardizer.standardize(from: providerResult, and: serviceResponse)
            log.info("Coordinator: Session refresh completed successfully for user \(user.id)")
            return user
        } catch {
            let finalError = (error as? AuthError) ?? AuthError.serviceError(error)
            log.error("Coordinator: Session refresh failed - \(finalError.localizedDescription)")
            throw finalError
        }
    }
    
    public func handleProviderCallback(url: URL) async -> Bool {
        log.info("Coordinator: Handling provider callback for URL: \(url.absoluteString)")
        
        // Try each provider to handle the callback
        for provider in providers.values {
            do {
                let providerTypeName = await provider.providerType.rawValue
                log.debug("Coordinator: Trying provider \(providerTypeName) for callback")
                if let _ = try await provider.handleCallback(url: url) {
                    log.info("Coordinator: Provider \(providerTypeName) successfully handled callback")
                    return true
                }
            } catch {
                let providerTypeName = await provider.providerType.rawValue
                log.debug("Coordinator: Provider \(providerTypeName) failed to handle callback: \(error.localizedDescription)")
                continue
            }
        }
        
        log.warning("Coordinator: No provider could handle the callback URL")
        return false
    }
}

// Extension to add provider property to ServiceUser for standardization
extension ServiceUser {
    var provider: AuthProviderType? {
        // This would need to be stored/tracked somehow
        // For now, return nil and let the standardizer handle it
        return nil
    }
}