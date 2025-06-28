import Foundation
import AuthenticationServices

public final class AppleAuthProvider: NSObject, AuthProvider, @unchecked Sendable {
    public let providerType: AuthProviderType = .apple
    public let redirectScheme: String? = nil
    public let requiredScopes: [String] = []
    
    private var currentContinuation: CheckedContinuation<ProviderAuthResult, Error>?
    
    public override init() {
        super.init()
    }
    
    public func authenticate() async throws -> ProviderAuthResult {
        return try await withCheckedThrowingContinuation { continuation in
            self.currentContinuation = continuation
            
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
    }
    
    public func handleCallback(url: URL) throws -> ProviderAuthResult? {
        return nil
    }
    
    public func refreshToken(_ refreshToken: String) async throws -> ProviderAuthResult {
        throw AuthError.providerError(.apple, NSError(domain: "AppleAuthProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple doesn't support token refresh"]))
    }
    
    public func signOut() async throws {
        // Apple doesn't require explicit sign out
    }
}

extension AppleAuthProvider: ASAuthorizationControllerDelegate {
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            currentContinuation?.resume(throwing: AuthError.providerError(.apple, NSError(domain: "AppleAuthProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid credential type"])))
            currentContinuation = nil
            return
        }
        
        guard let identityToken = appleIDCredential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8) else {
            currentContinuation?.resume(throwing: AuthError.providerError(.apple, NSError(domain: "AppleAuthProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get identity token"])))
            currentContinuation = nil
            return
        }
        
        var userInfo: [String: AnySendableValue] = [:]
        userInfo["user_id"] = AnySendableValue(appleIDCredential.user)
        if let email = appleIDCredential.email {
            userInfo["email"] = AnySendableValue(email)
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
        
        currentContinuation?.resume(returning: result)
        currentContinuation = nil
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                currentContinuation?.resume(throwing: AuthError.cancelled)
            default:
                currentContinuation?.resume(throwing: AuthError.providerError(.apple, error))
            }
        } else {
            currentContinuation?.resume(throwing: AuthError.providerError(.apple, error))
        }
        currentContinuation = nil
    }
}

extension AppleAuthProvider: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if os(iOS)
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? UIWindow()
        #elseif os(macOS)
        return NSApplication.shared.windows.first ?? NSWindow()
        #else
        fatalError("Unsupported platform")
        #endif
    }
}