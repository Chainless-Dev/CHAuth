import Foundation
import AppAuth
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
    private let issuer: String
    private var currentAuthSession: OIDExternalUserAgentSession?
    
    public init(
        clientID: String,
        redirectScheme: String,
        issuer: String = "https://accounts.google.com",
        scopes: [String] = ["openid", "profile", "email"]
    ) {
        self.clientID = clientID
        self.redirectScheme = redirectScheme
        self.issuer = issuer
        self.requiredScopes = scopes
    }
    
    public func authenticate() async throws -> ProviderAuthResult {
        log.info("GoogleProvider: Starting Google authentication")
        
        return try await withCheckedThrowingContinuation { continuation in
            guard let issuerURL = URL(string: issuer) else {
                log.error("GoogleProvider: Invalid issuer URL: \(issuer)")
                continuation.resume(throwing: AuthError.configurationError("Invalid issuer URL"))
                return
            }
            
            log.debug("GoogleProvider: Discovering OAuth configuration for issuer: \(issuer)")
            OIDAuthorizationService.discoverConfiguration(forIssuer: issuerURL) { [weak self] configuration, error in
                guard let self = self else {
                    continuation.resume(throwing: AuthError.unknown(NSError(domain: "GoogleAuthProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Provider deallocated"])))
                    return
                }
                
                if let error = error {
                    log.error("GoogleProvider: Configuration discovery failed: \(error.localizedDescription)")
                    continuation.resume(throwing: AuthError.providerError(.google, error))
                    return
                }
                
                guard let configuration = configuration else {
                    log.error("GoogleProvider: Failed to discover OAuth configuration")
                    continuation.resume(throwing: AuthError.configurationError("Failed to discover OAuth configuration"))
                    return
                }
                
                log.debug("GoogleProvider: Creating authorization request with scopes: \(self.requiredScopes.joined(separator: ", "))")
                let request = OIDAuthorizationRequest(
                    configuration: configuration,
                    clientId: self.clientID,
                    scopes: self.requiredScopes,
                    redirectURL: URL(string: self.redirectScheme!)!,
                    responseType: OIDResponseTypeCode,
                    additionalParameters: nil
                )
                
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
                
                log.debug("GoogleProvider: Presenting authorization request")
                self.currentAuthSession = OIDAuthState.authState(byPresenting: request, presenting: presentingViewController) { authState, error in
                    self.handleAuthResult(authState: authState, error: error, continuation: continuation)
                }
                #elseif os(macOS)
                log.debug("GoogleProvider: Presenting authorization request (macOS)")
                self.currentAuthSession = OIDAuthState.authState(byPresenting: request) { authState, error in
                    self.handleAuthResult(authState: authState, error: error, continuation: continuation)
                }
                #endif
            }
        }
    }
    
    private func handleAuthResult(
        authState: OIDAuthState?,
        error: Error?,
        continuation: CheckedContinuation<ProviderAuthResult, Error>
    ) {
        if let error = error {
            log.error("GoogleProvider: Authentication failed: \(error.localizedDescription)")
            continuation.resume(throwing: AuthError.providerError(.google, error))
            return
        }
        
        guard let authState = authState,
              let accessToken = authState.lastTokenResponse?.accessToken else {
            log.error("GoogleProvider: Failed to get access token from auth state")
            continuation.resume(throwing: AuthError.providerError(.google, NSError(domain: "GoogleAuthProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get access token"])))
            return
        }
        
        log.debug("GoogleProvider: Processing authentication result")
        var userInfo: [String: AnySendableValue] = [:]
        
        if let idToken = authState.lastTokenResponse?.idToken {
            log.debug("GoogleProvider: ID token received, parsing user info")
            userInfo["id_token"] = AnySendableValue(idToken)
            
            // Parse ID token for user info (simplified - in production use a proper JWT library)
            if let payload = parseJWTPayload(idToken) {
                for (key, value) in payload {
                    userInfo[key] = AnySendableValue(value)
                }
                log.debug("GoogleProvider: Parsed user info from ID token")
            }
        }
        
        let result = ProviderAuthResult(
            accessToken: accessToken,
            refreshToken: authState.refreshToken,
            idToken: authState.lastTokenResponse?.idToken,
            expiresAt: authState.lastTokenResponse?.accessTokenExpirationDate,
            scope: authState.lastTokenResponse?.scope,
            userInfo: userInfo,
            provider: .google
        )
        
        log.info("GoogleProvider: Authentication successful")
        continuation.resume(returning: result)
    }
    
    public func handleCallback(url: URL) throws -> ProviderAuthResult? {
        log.debug("GoogleProvider: Handling callback URL: \(url.absoluteString)")
        
        if currentAuthSession?.resumeExternalUserAgentFlow(with: url) == true {
            log.debug("GoogleProvider: Callback handled by external user agent flow")
            return nil // Will be handled by the completion handler
        }
        
        log.debug("GoogleProvider: Callback not handled by current session")
        return nil
    }
    
    public func refreshToken(_ refreshToken: String) async throws -> ProviderAuthResult {
        log.info("GoogleProvider: Starting token refresh")
        
        return try await withCheckedThrowingContinuation { continuation in
            guard let issuerURL = URL(string: issuer) else {
                log.error("GoogleProvider: Invalid issuer URL for refresh: \(issuer)")
                continuation.resume(throwing: AuthError.configurationError("Invalid issuer URL"))
                return
            }
            
            OIDAuthorizationService.discoverConfiguration(forIssuer: issuerURL) { [weak self] configuration, error in
                guard let self = self else {
                    continuation.resume(throwing: AuthError.unknown(NSError(domain: "GoogleAuthProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Provider deallocated"])))
                    return
                }
                
                if let error = error {
                    continuation.resume(throwing: AuthError.providerError(.google, error))
                    return
                }
                
                guard let configuration = configuration else {
                    continuation.resume(throwing: AuthError.configurationError("Failed to discover OAuth configuration"))
                    return
                }
                
                let request = OIDTokenRequest(
                    configuration: configuration,
                    grantType: OIDGrantTypeRefreshToken,
                    authorizationCode: nil,
                    redirectURL: nil,
                    clientID: self.clientID,
                    clientSecret: nil,
                    scope: nil,
                    refreshToken: refreshToken,
                    codeVerifier: nil,
                    additionalParameters: nil
                )
                
                OIDAuthorizationService.perform(request) { response, error in
                    if let error = error {
                        continuation.resume(throwing: AuthError.providerError(.google, error))
                        return
                    }
                    
                    guard let response = response,
                          let accessToken = response.accessToken else {
                        continuation.resume(throwing: AuthError.providerError(.google, NSError(domain: "GoogleAuthProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to refresh token"])))
                        return
                    }
                    
                    var userInfo: [String: AnySendableValue] = [:]
                    
                    if let idToken = response.idToken {
                        userInfo["id_token"] = AnySendableValue(idToken)
                        
                        if let payload = self.parseJWTPayload(idToken) {
                            for (key, value) in payload {
                                userInfo[key] = AnySendableValue(value)
                            }
                        }
                    }
                    
                    let result = ProviderAuthResult(
                        accessToken: accessToken,
                        refreshToken: response.refreshToken ?? refreshToken,
                        idToken: response.idToken,
                        expiresAt: response.accessTokenExpirationDate,
                        scope: response.scope,
                        userInfo: userInfo,
                        provider: .google
                    )
                    
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    public func signOut() async throws {
        log.info("GoogleProvider: Signing out")
        currentAuthSession = nil
        log.debug("GoogleProvider: Sign out completed")
    }
    
    private func parseJWTPayload(_ jwt: String) -> [String: Any]? {
        let segments = jwt.components(separatedBy: ".")
        guard segments.count > 1 else { return nil }
        
        let payloadSegment = segments[1]
        var base64 = payloadSegment
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        while base64.count % 4 != 0 {
            base64 += "="
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        return json
    }
}