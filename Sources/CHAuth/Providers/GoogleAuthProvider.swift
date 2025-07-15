import Foundation
import GoogleSignIn
import CHLogger
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
public final class GoogleAuthProvider: NSObject, AuthProvider {
    public let providerType: AuthProviderType = .google
    public let redirectScheme: String?
    public let requiredScopes: [String]
    
    private let clientID: String
    private var configuration: GIDConfiguration
    
    public init(
        clientID: String,
        redirectScheme: String,
        issuer: String = "https://accounts.google.com",
        scopes: [String] = ["openid", "profile", "email"]
    ) {
        self.clientID = clientID
        self.redirectScheme = redirectScheme
        self.requiredScopes = scopes
        self.configuration = GIDConfiguration(clientID: clientID)
        
        super.init()
        
        GIDSignIn.sharedInstance.configuration = configuration
    }
    
    public func authenticate() async throws -> ProviderAuthResult {
        log.info("GoogleProvider: Starting Google authentication")
        
        return try await withCheckedThrowingContinuation { continuation in
            #if os(iOS)
            // Get the root view controller from the active window scene
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
                  let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
                  let presentingViewController = keyWindow.rootViewController else {
                log.error("GoogleProvider: No presenting view controller available")
                continuation.resume(throwing: AuthError.configurationError("No presenting view controller available"))
                return
            }
            
            log.debug("GoogleProvider: Presenting Google Sign-In")
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController, hint: nil, additionalScopes: self.requiredScopes) { [weak self] result, error in
                self?.handleSignInResult(result: result, error: error, continuation: continuation)
            }
            #elseif os(macOS)
            guard let presentingWindow = NSApplication.shared.mainWindow else {
                log.error("GoogleProvider: No presenting window available")
                continuation.resume(throwing: AuthError.configurationError("No presenting window available"))
                return
            }
            
            log.debug("GoogleProvider: Presenting Google Sign-In (macOS)")
            GIDSignIn.sharedInstance.signIn(withPresenting: presentingWindow, hint: nil, additionalScopes: self.requiredScopes) { [weak self] result, error in
                self?.handleSignInResult(result: result, error: error, continuation: continuation)
            }
            #endif
        }
    }
    
    private func handleSignInResult(
        result: GIDSignInResult?,
        error: Error?,
        continuation: CheckedContinuation<ProviderAuthResult, Error>
    ) {
        if let error = error {
            log.error("GoogleProvider: Authentication failed: \(error.localizedDescription)")
            continuation.resume(throwing: AuthError.providerError(.google, error))
            return
        }
        
        guard let result = result else {
            log.error("GoogleProvider: Failed to get sign-in result")
            continuation.resume(throwing: AuthError.providerError(.google, NSError(domain: "GoogleAuthProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get sign-in result"])))
            return
        }
        
        let user = result.user
        let accessToken = user.accessToken.tokenString
        
        log.debug("GoogleProvider: Processing authentication result")
        var userInfo: [String: AnySendableValue] = [:]
        
        // Extract user information from Google Sign-In result
        if let profile = user.profile {
            userInfo["name"] = AnySendableValue(profile.name)
            userInfo["given_name"] = AnySendableValue(profile.givenName ?? "")
            userInfo["family_name"] = AnySendableValue(profile.familyName ?? "")
            userInfo["email"] = AnySendableValue(profile.email)
            userInfo["picture"] = AnySendableValue(profile.imageURL(withDimension: 200)?.absoluteString ?? "")
            userInfo["sub"] = AnySendableValue(user.userID ?? "")
            userInfo["email_verified"] = AnySendableValue(profile.hasImage)
        }
        
        if let idToken = user.idToken?.tokenString {
            userInfo["id_token"] = AnySendableValue(idToken)
            log.debug("GoogleProvider: ID token received")
        }
        
        let providerResult = ProviderAuthResult(
            accessToken: accessToken,
            refreshToken: user.refreshToken.tokenString,
            idToken: user.idToken?.tokenString,
            expiresAt: user.accessToken.expirationDate,
            scope: user.grantedScopes?.joined(separator: " "),
            userInfo: userInfo,
            provider: .google
        )
        
        log.info("GoogleProvider: Authentication successful")
        continuation.resume(returning: providerResult)
    }
    
    public func handleCallback(url: URL) throws -> ProviderAuthResult? {
        log.debug("GoogleProvider: Handling callback URL: \(url.absoluteString)")
        
        // Google Sign-In iOS SDK handles URL schemes automatically
        // This method is kept for compatibility but isn't needed for Google Sign-In
        if GIDSignIn.sharedInstance.handle(url) {
            log.debug("GoogleProvider: Callback handled by Google Sign-In")
            return nil // Will be handled by the completion handler
        }
        
        log.debug("GoogleProvider: Callback not handled by Google Sign-In")
        return nil
    }
    
    public func refreshToken(_ refreshToken: String) async throws -> ProviderAuthResult {
        log.info("GoogleProvider: Starting token refresh")
        
        return try await withCheckedThrowingContinuation { continuation in
            guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
                log.error("GoogleProvider: No current user available for token refresh")
                continuation.resume(throwing: AuthError.configurationError("No current user available"))
                return
            }
            
            log.debug("GoogleProvider: Refreshing access token")
            currentUser.refreshTokensIfNeeded { user, error in
                if let error = error {
                    log.error("GoogleProvider: Token refresh failed: \(error.localizedDescription)")
                    continuation.resume(throwing: AuthError.providerError(.google, error))
                    return
                }
                
                guard let user = user else {
                    log.error("GoogleProvider: Failed to get refreshed user")
                    continuation.resume(throwing: AuthError.providerError(.google, NSError(domain: "GoogleAuthProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to refresh token"])))
                    return
                }
                
                let accessToken = user.accessToken.tokenString
                
                var userInfo: [String: AnySendableValue] = [:]
                
                // Extract user information from refreshed user
                if let profile = user.profile {
                    userInfo["name"] = AnySendableValue(profile.name)
                    userInfo["given_name"] = AnySendableValue(profile.givenName ?? "")
                    userInfo["family_name"] = AnySendableValue(profile.familyName ?? "")
                    userInfo["email"] = AnySendableValue(profile.email)
                    userInfo["picture"] = AnySendableValue(profile.imageURL(withDimension: 200)?.absoluteString ?? "")
                    userInfo["sub"] = AnySendableValue(user.userID ?? "")
                    userInfo["email_verified"] = AnySendableValue(profile.hasImage)
                }
                
                if let idToken = user.idToken?.tokenString {
                    userInfo["id_token"] = AnySendableValue(idToken)
                }
                
                let providerResult = ProviderAuthResult(
                    accessToken: accessToken,
                    refreshToken: user.refreshToken.tokenString,
                    idToken: user.idToken?.tokenString,
                    expiresAt: user.accessToken.expirationDate,
                    scope: user.grantedScopes?.joined(separator: " "),
                    userInfo: userInfo,
                    provider: .google
                )
                
                log.info("GoogleProvider: Token refresh successful")
                continuation.resume(returning: providerResult)
            }
        }
    }
    
    public func signOut() async throws {
        log.info("GoogleProvider: Signing out")
        GIDSignIn.sharedInstance.signOut()
        log.debug("GoogleProvider: Sign out completed")
    }
}
