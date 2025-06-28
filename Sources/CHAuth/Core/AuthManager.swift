import Foundation
import Combine

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
            manager.sessionManager = sessionManager ?? KeychainSessionManager(authService: service)
            manager.coordinator = coordinator ?? DefaultAuthCoordinator(
                providers: Dictionary(uniqueKeysWithValues: providers.map { ($0.providerType, $0) }),
                authService: service,
                sessionManager: manager.sessionManager!,
                userStandardizer: DefaultUserProfileStandardizer()
            )
            
            await manager.checkExistingSession()
        }
    }
    
    public func signIn(with provider: AuthProviderType) async {
        authState = .authenticating(provider)
        lastError = nil
        
        do {
            guard let coordinator = coordinator else {
                throw AuthError.configurationError("AuthManager not configured")
            }
            
            let user = try await coordinator.signIn(with: provider)
            currentUser = user
            authState = .authenticated(user)
        } catch {
            let authError = error as? AuthError ?? AuthError.unknown(error)
            lastError = authError
            authState = .error(authError)
            currentUser = nil
        }
    }
    
    public func signOut() async {
        do {
            try await coordinator?.signOut()
            currentUser = nil
            authState = .unauthenticated
            lastError = nil
        } catch {
            let authError = error as? AuthError ?? AuthError.unknown(error)
            lastError = authError
            authState = .error(authError)
        }
    }
    
    public func refreshSession() async -> Bool {
        guard let coordinator = coordinator else {
            return false
        }
        
        authState = .refreshing
        
        do {
            let user = try await coordinator.refreshSession()
            currentUser = user
            authState = .authenticated(user)
            return true
        } catch {
            let authError = error as? AuthError ?? AuthError.unknown(error)
            lastError = authError
            authState = .error(authError)
            currentUser = nil
            return false
        }
    }
    
    public func deleteAccount() async throws {
        guard let accessToken = await sessionManager?.currentAccessToken else {
            throw AuthError.sessionExpired
        }
        
        guard let coordinator = coordinator else {
            throw AuthError.configurationError("AuthManager not configured")
        }
        
        // This would need to be implemented in the coordinator/service
        // For now, just sign out
        await signOut()
    }
    
    private func checkExistingSession() async {
        guard let sessionManager = sessionManager else { return }
        
        if await sessionManager.isSessionValid() {
            _ = await refreshSession()
        }
    }
}