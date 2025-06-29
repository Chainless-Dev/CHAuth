import Foundation
import AuthenticationServices
import CHLogger
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
public final class AppleAuthProvider: NSObject, AuthProvider {
    public let providerType: AuthProviderType = .apple
    public let redirectScheme: String? = nil
    public let requiredScopes: [String] = []
    
    private var currentContinuation: CheckedContinuation<ProviderAuthResult, Error>?
    
    public override init() {
        super.init()
    }
    
    public func authenticate() async throws -> ProviderAuthResult {
        log.info("AppleProvider: Starting Apple authentication")
        
        return try await withCheckedThrowingContinuation { continuation in
            self.currentContinuation = continuation
            
            log.debug("AppleProvider: Creating Apple ID request with fullName and email scopes")
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            
            log.debug("AppleProvider: Performing authorization requests")
            authorizationController.performRequests()
        }
    }
    
    public func handleCallback(url: URL) throws -> ProviderAuthResult? {
        log.debug("AppleProvider: Handle callback called, but Apple doesn't use URL callbacks")
        return nil
    }
    
    public func refreshToken(_ refreshToken: String) async throws -> ProviderAuthResult {
        log.warning("AppleProvider: Token refresh attempted, but Apple doesn't support token refresh")
        throw AuthError.providerError(.apple, NSError(domain: "AppleAuthProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple doesn't support token refresh"]))
    }
    
    public func signOut() async throws {
        log.debug("AppleProvider: Sign out called - Apple doesn't require explicit sign out")
        // Apple doesn't require explicit sign out
    }
}

extension AppleAuthProvider: ASAuthorizationControllerDelegate {
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        log.debug("AppleProvider: Authorization completed successfully")
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            log.error("AppleProvider: Invalid credential type received")
            currentContinuation?.resume(throwing: AuthError.providerError(.apple, NSError(domain: "AppleAuthProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid credential type"])))
            currentContinuation = nil
            return
        }
        
        guard let identityToken = appleIDCredential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8) else {
            log.error("AppleProvider: Failed to get identity token from credential")
            currentContinuation?.resume(throwing: AuthError.providerError(.apple, NSError(domain: "AppleAuthProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get identity token"])))
            currentContinuation = nil
            return
        }
        
        log.debug("AppleProvider: Processing user credentials")
        var userInfo: [String: AnySendableValue] = [:]
        userInfo["user_id"] = AnySendableValue(appleIDCredential.user)
        
        if let email = appleIDCredential.email {
            log.debug("AppleProvider: Email provided: \(email)")
            userInfo["email"] = AnySendableValue(email)
        } else {
            log.debug("AppleProvider: No email provided")
        }
        
        if let fullName = appleIDCredential.fullName {
            if let givenName = fullName.givenName {
                userInfo["given_name"] = AnySendableValue(givenName)
            }
            if let familyName = fullName.familyName {
                userInfo["family_name"] = AnySendableValue(familyName)
            }
            
            let displayName = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            if !displayName.isEmpty {
                userInfo["full_name"] = AnySendableValue(displayName)
                log.debug("AppleProvider: Full name provided: \(displayName)")
            }
        }
        
        let result = ProviderAuthResult(
            accessToken: identityTokenString,
            refreshToken: nil,
            idToken: identityTokenString,
            expiresAt: nil,
            scope: nil,
            userInfo: userInfo,
            provider: .apple
        )
        
        log.info("AppleProvider: Authentication successful for user \(appleIDCredential.user)")
        currentContinuation?.resume(returning: result)
        currentContinuation = nil
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        log.error("AppleProvider: Authorization failed with error: \(error.localizedDescription)")
        
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                log.info("AppleProvider: User cancelled authentication")
                currentContinuation?.resume(throwing: AuthError.cancelled)
            default:
                log.error("AppleProvider: ASAuthorization error: \(authError.localizedDescription)")
                currentContinuation?.resume(throwing: AuthError.providerError(.apple, error))
            }
        } else {
            log.error("AppleProvider: Unexpected error type: \(error.localizedDescription)")
            currentContinuation?.resume(throwing: AuthError.providerError(.apple, error))
        }
        currentContinuation = nil
    }
}

extension AppleAuthProvider: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if os(iOS)
        // Get the first active window scene and its key window
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            // Fallback: create a new window if no active scene
            return UIWindow()
        }
        
        // Get the key window from the active scene
        guard let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            // Fallback: get any window from the scene or create new one
            return windowScene.windows.first ?? UIWindow()
        }
        
        return keyWindow
        #elseif os(macOS)
        return NSApplication.shared.windows.first ?? NSWindow()
        #else
        fatalError("Unsupported platform")
        #endif
    }
}