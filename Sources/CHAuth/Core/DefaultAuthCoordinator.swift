import Foundation

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
        guard let provider = providers[providerType] else {
            throw AuthError.configurationError("Provider \(providerType.rawValue) not configured")
        }
        
        do {
            // Since provider is MainActor, we need to call it from MainActor context
            let providerResult = try await provider.authenticate()
            let serviceResponse = try await authService.signIn(with: providerResult)
            
            let tokens = AuthTokens(
                accessToken: serviceResponse.accessToken,
                refreshToken: serviceResponse.refreshToken,
                expiresAt: serviceResponse.expiresAt,
                tokenType: serviceResponse.tokenType
            )
            
            try await sessionManager.store(tokens: tokens)
            
            let user = userStandardizer.standardize(from: providerResult, and: serviceResponse)
            return user
        } catch {
            if let authError = error as? AuthError {
                throw authError
            } else {
                throw AuthError.providerError(providerType, error)
            }
        }
    }
    
    public func signOut() async throws {
        if let accessToken = await sessionManager.currentAccessToken {
            try await authService.signOut(token: accessToken)
        }
        
        try await sessionManager.clearSession()
    }
    
    public func refreshSession() async throws -> User {
        guard let refreshToken = await sessionManager.currentRefreshToken else {
            throw AuthError.sessionExpired
        }
        
        do {
            let serviceResponse = try await authService.refreshSession(refreshToken: refreshToken)
            
            let tokens = AuthTokens(
                accessToken: serviceResponse.accessToken,
                refreshToken: serviceResponse.refreshToken,
                expiresAt: serviceResponse.expiresAt,
                tokenType: serviceResponse.tokenType
            )
            
            try await sessionManager.store(tokens: tokens)
            
            // Create a dummy provider result for standardization
            let providerResult = ProviderAuthResult(
                accessToken: serviceResponse.accessToken,
                provider: serviceResponse.user.provider ?? .apple // Default fallback
            )
            
            let user = userStandardizer.standardize(from: providerResult, and: serviceResponse)
            return user
        } catch {
            if let authError = error as? AuthError {
                throw authError
            } else {
                throw AuthError.serviceError(error)
            }
        }
    }
    
    public func handleProviderCallback(url: URL) async -> Bool {
        // Try each provider to handle the callback
        for provider in providers.values {
            do {
                if let _ = try await provider.handleCallback(url: url) {
                    return true
                }
            } catch {
                continue
            }
        }
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