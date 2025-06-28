import Foundation
import Supabase
import CHAuth

public final class SupabaseAuthService: AuthService, @unchecked Sendable {
    private let supabase: SupabaseClient
    
    public init(supabase: SupabaseClient) {
        self.supabase = supabase
    }
    
    public func signIn(with result: ProviderAuthResult) async throws -> CHAuth.AuthResponse {
        do {
            let session: Session
            
            switch result.provider {
            case .apple:
                guard let idToken = result.idToken else {
                    throw AuthError.providerError(.apple, NSError(domain: "SupabaseAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing ID token"]))
                }
                
                session = try await supabase.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: idToken
                    )
                )
                
            case .google:
                guard let idToken = result.idToken else {
                    throw AuthError.providerError(.google, NSError(domain: "SupabaseAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing ID token"]))
                }
                
                session = try await supabase.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .google,
                        idToken: idToken,
                        accessToken: result.accessToken
                    )
                )
                
            case .github:
                // GitHub OAuth not directly supported by Supabase OpenIDConnect
                // This would need custom implementation or different auth method
                throw AuthError.providerError(.github, NSError(domain: "SupabaseAuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "GitHub OAuth not implemented"]))
            }
            
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
            
            return CHAuth.AuthResponse(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                user: serviceUser,
                expiresAt: Date(timeIntervalSince1970: TimeInterval(session.expiresAt)),
                tokenType: session.tokenType ?? "Bearer"
            )
            
        } catch {
            throw AuthError.serviceError(error)
        }
    }
    
    public func signOut(token: String) async throws {
        do {
            try await supabase.auth.signOut()
        } catch {
            throw AuthError.serviceError(error)
        }
    }
    
    public func refreshSession(refreshToken: String) async throws -> CHAuth.AuthResponse {
        do {
            let session = try await supabase.auth.refreshSession(refreshToken: refreshToken)
            
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
            
            return CHAuth.AuthResponse(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken,
                user: serviceUser,
                expiresAt: Date(timeIntervalSince1970: TimeInterval(session.expiresAt)),
                tokenType: session.tokenType ?? "Bearer"
            )
            
        } catch {
            throw AuthError.serviceError(error)
        }
    }
    
    public func getUserProfile(accessToken: String) async throws -> CHAuth.User {
        do {
            let user = try await supabase.auth.user()
            
            return CHAuth.User(
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
            
        } catch {
            throw AuthError.serviceError(error)
        }
    }
    
    public func deleteAccount(accessToken: String) async throws {
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