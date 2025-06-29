import Foundation
import Combine
import CHLogger

@MainActor
public class AuthManager: ObservableObject {
    public static let shared = AuthManager()
    
    @Published public private(set) var currentUser: User?
    @Published public private(set) var authState: AuthState = .unauthenticated
    @Published public private(set) var lastError: AuthError?
    
    private var coordinator: AuthCoordinator?
    private var sessionManager: SessionManager?
    
    public var isAuthenticated: Bool {
        currentUser != nil
    }
    
    public var accessToken: String? {
        get async {
            await sessionManager?.currentAccessToken
        }
    }
    
    private init() {}
    
    public static func configure(
        service: AuthService,
        providers: [AuthProvider],
        sessionManager: SessionManager? = nil,
        coordinator: AuthCoordinator? = nil
    ) {
        Task { @MainActor in
            let manager = AuthManager.shared
            log.info("Configuring AuthManager with \(providers.count) providers")
            
            manager.sessionManager = sessionManager ?? KeychainSessionManager(authService: service)
            manager.coordinator = coordinator ?? DefaultAuthCoordinator(
                providers: Dictionary(uniqueKeysWithValues: providers.map { ($0.providerType, $0) }),
                authService: service,
                sessionManager: manager.sessionManager!,
                userStandardizer: DefaultUserProfileStandardizer()
            )
            
            log.debug("Providers configured: \(providers.map(\.providerType.rawValue).joined(separator: ", "))")
            await manager.checkExistingSession()
        }
    }
    
    public func signIn(with provider: AuthProviderType) async {
        log.info("Starting sign in with provider: \(provider.rawValue)")
        authState = .authenticating(provider)
        lastError = nil
        
        do {
            guard let coordinator = coordinator else {
                log.error("AuthManager not configured - coordinator is nil")
                throw AuthError.configurationError("AuthManager not configured")
            }
            
            log.debug("Delegating sign in to coordinator")
            let user = try await coordinator.signIn(with: provider)
            currentUser = user
            authState = .authenticated(user)
            log.info("Sign in successful for user: \(user.id)")
        } catch {
            let authError = error as? AuthError ?? AuthError.unknown(error)
            log.error("Sign in failed: \(authError.localizedDescription)")
            lastError = authError
            authState = .error(authError)
            currentUser = nil
        }
    }
    
    public func signOut() async {
        log.info("Starting sign out")
        do {
            try await coordinator?.signOut()
            currentUser = nil
            authState = .unauthenticated
            lastError = nil
            log.info("Sign out successful")
        } catch {
            let authError = error as? AuthError ?? AuthError.unknown(error)
            log.error("Sign out failed: \(authError.localizedDescription)")
            lastError = authError
            authState = .error(authError)
        }
    }
    
    public func refreshSession() async -> Bool {
        log.debug("Starting session refresh")
        guard let coordinator = coordinator else {
            log.warning("Cannot refresh session - coordinator is nil")
            return false
        }
        
        authState = .refreshing
        
        do {
            let user = try await coordinator.refreshSession()
            currentUser = user
            authState = .authenticated(user)
            log.info("Session refresh successful for user: \(user.id)")
            return true
        } catch {
            let authError = error as? AuthError ?? AuthError.unknown(error)
            log.error("Session refresh failed: \(authError.localizedDescription)")
            lastError = authError
            authState = .error(authError)
            currentUser = nil
            return false
        }
    }
    
    public func deleteAccount() async throws {
        guard await sessionManager?.currentAccessToken != nil else {
            throw AuthError.sessionExpired
        }
        
        guard coordinator != nil else {
            throw AuthError.configurationError("AuthManager not configured")
        }
        
        // This would need to be implemented in the coordinator/service
        // For now, just sign out
        await signOut()
    }
    
    private func checkExistingSession() async {
        log.debug("Checking for existing session")
        guard let sessionManager = sessionManager else { 
            log.debug("No session manager available")
            return 
        }
        
        if await sessionManager.isSessionValid() {
            log.info("Valid session found, attempting to refresh")
            _ = await refreshSession()
        } else {
            log.debug("No valid session found")
        }
    }
}
