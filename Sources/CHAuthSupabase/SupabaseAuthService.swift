import Foundation
import Supabase
import CHAuth
import CHLogger

public final class SupabaseAuthService: AuthService, @unchecked Sendable {
    private let supabase: SupabaseClient
    
    public init(supabase: SupabaseClient) {
        self.supabase = supabase
    }
    
    public func signIn(with result: ProviderAuthResult) async throws -> CHAuth.AuthResponse {
        log.info("SupabaseService: Starting sign in with provider \(result.provider.rawValue)")
        
        do {
            let session: Session
            
            switch result.provider {
            case .apple:
                log.debug("SupabaseService: Signing in with Apple ID token")
                guard let idToken = result.idToken else {
                    log.error("SupabaseService: Missing ID token for Apple sign in")
                    throw AuthError.providerError(.apple, NSError(domain: "SupabaseAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing ID token"]))
                }
                
                session = try await supabase.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: idToken
                    )
                )
                
            case .google:
                log.debug("SupabaseService: Signing in with Google ID token")
                guard let idToken = result.idToken else {
                    log.error("SupabaseService: Missing ID token for Google sign in")
                    throw AuthError.providerError(.google, NSError(domain: "SupabaseAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing ID token"]))
                }
                
                session = try await supabase.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .google,
                        idToken: idToken,
                        accessToken: result.accessToken
                    )
                )
            }
            
            log.debug("SupabaseService: Creating service user from session")
            let serviceUser = ServiceUser(
                id: session.user.id.uuidString,
                email: session.user.email,
                fullName: session.user.userMetadata["full_name"]?.value as? String,
                avatarURL: {
                    if let avatarURLString = session.user.userMetadata["avatar_url"]?.value as? String {
                        return URL(string: avatarURLString)
                    }
                    return nil
                }(),
                createdAt: session.user.createdAt,
                lastSignInAt: session.user.lastSignInAt ?? Date()
            )
            
            log.info("SupabaseService: Sign in successful for user \\(serviceUser.id)")
            return CHAuth.AuthResponse(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                user: serviceUser,
                expiresAt: Date(timeIntervalSince1970: TimeInterval(session.expiresAt)),
                tokenType: session.tokenType ?? "Bearer"
            )
            
        } catch {
            log.error("SupabaseService: Sign in failed: \\(error.localizedDescription)")
            throw AuthError.serviceError(error)
        }
    }
    
    public func signOut(token: String) async throws {
        log.info("SupabaseService: Starting sign out")
        
        do {
            try await supabase.auth.signOut()
            log.info("SupabaseService: Sign out successful")
        } catch {
            log.error("SupabaseService: Sign out failed: \(error.localizedDescription)")
            throw AuthError.serviceError(error)
        }
    }
    
    public func refreshSession(refreshToken: String) async throws -> CHAuth.AuthResponse {
        log.info("SupabaseService: Starting session refresh")
        
        do {
            let session = try await supabase.auth.refreshSession(refreshToken: refreshToken)
            
            log.debug("SupabaseService: Creating service user from refreshed session")
            let serviceUser = ServiceUser(
                id: session.user.id.uuidString,
                email: session.user.email,
                fullName: session.user.userMetadata["full_name"]?.value as? String,
                avatarURL: {
                    if let avatarURLString = session.user.userMetadata["avatar_url"]?.value as? String {
                        return URL(string: avatarURLString)
                    }
                    return nil
                }(),
                createdAt: session.user.createdAt,
                lastSignInAt: session.user.lastSignInAt ?? Date()
            )
            
            log.info("SupabaseService: Session refresh successful for user \(serviceUser.id)")
            return CHAuth.AuthResponse(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                user: serviceUser,
                expiresAt: Date(timeIntervalSince1970: TimeInterval(session.expiresAt)),
                tokenType: session.tokenType ?? "Bearer"
            )
            
        } catch {
            log.error("SupabaseService: Session refresh failed: \(error.localizedDescription)")
            throw AuthError.serviceError(error)
        }
    }
    
    public func getUserProfile(accessToken: String) async throws -> CHAuth.User {
        log.info("SupabaseService: Getting user profile")
        
        do {
            let user = try await supabase.auth.user()
            
            log.debug("SupabaseService: Creating CHAuth user from Supabase user")
            let chAuthUser = CHAuth.User(
                id: user.id.uuidString,
                email: user.email,
                fullName: user.userMetadata["full_name"]?.value as? String,
                givenName: user.userMetadata["given_name"]?.value as? String,
                familyName: user.userMetadata["family_name"]?.value as? String,
                avatarURL: {
                    if let avatarURLString = user.userMetadata["avatar_url"]?.value as? String {
                        return URL(string: avatarURLString)
                    }
                    return nil
                }(),
                provider: determineProvider(from: user),
                createdAt: user.createdAt,
                lastSignInAt: user.lastSignInAt ?? Date()
            )
            
            log.info("SupabaseService: User profile retrieved successfully for user \\(chAuthUser.id)")
            return chAuthUser
            
        } catch {
            log.error("SupabaseService: Failed to get user profile: \\(error.localizedDescription)")
            throw AuthError.serviceError(error)
        }
    }
    
    public func deleteAccount(accessToken: String) async throws {
        log.warning("SupabaseService: Account deletion attempted but not implemented")
        // Supabase doesn't have a direct delete account method in the auth API
        // This would typically require a custom RPC call or edge function
        throw AuthError.serviceError(NSError(domain: "SupabaseAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Account deletion not implemented"]))
    }
    
    private func determineProvider(from user: Supabase.User) -> AuthProviderType {
        // Try to determine provider from user metadata or app metadata
        if let provider = user.appMetadata["provider"]?.value as? String {
            return AuthProviderType(rawValue: provider) ?? .apple
        }
        
        // Fallback to checking identities
        if let identity = user.identities?.first {
            return AuthProviderType(rawValue: identity.provider) ?? .apple
        }
        
        return .apple // Default fallback
    }
}
