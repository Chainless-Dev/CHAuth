import Foundation
import AppAuth

public final class GoogleAuthProvider: NSObject, AuthProvider, @unchecked Sendable {
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
        return try await withCheckedThrowingContinuation { continuation in
            guard let issuerURL = URL(string: issuer) else {
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
                
                let request = OIDAuthorizationRequest(
                    configuration: configuration,
                    clientId: self.clientID,
                    scopes: self.requiredScopes,
                    redirectURL: URL(string: self.redirectScheme!)!,
                    responseType: OIDResponseTypeCode,
                    additionalParameters: nil
                )
                
                #if os(iOS)
                guard let presentingViewController = UIApplication.shared.windows.first?.rootViewController else {
                    continuation.resume(throwing: AuthError.configurationError("No presenting view controller available"))
                    return
                }
                
                self.currentAuthSession = OIDAuthState.authState(byPresenting: request, presenting: presentingViewController) { authState, error in
                    self.handleAuthResult(authState: authState, error: error, continuation: continuation)
                }
                #elseif os(macOS)
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
            continuation.resume(throwing: AuthError.providerError(.google, error))
            return
        }
        
        guard let authState = authState,
              let accessToken = authState.lastTokenResponse?.accessToken else {
            continuation.resume(throwing: AuthError.providerError(.google, NSError(domain: "GoogleAuthProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get access token"])))
            return
        }
        
        var userInfo: [String: AnySendableValue] = [:]
        
        if let idToken = authState.lastTokenResponse?.idToken {
            userInfo["id_token"] = AnySendableValue(idToken)
            
            // Parse ID token for user info (simplified - in production use a proper JWT library)
            if let payload = parseJWTPayload(idToken) {
                for (key, value) in payload {
                    userInfo[key] = AnySendableValue(value)
                }
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
        
        continuation.resume(returning: result)
    }
    
    public func handleCallback(url: URL) throws -> ProviderAuthResult? {
        if currentAuthSession?.resumeExternalUserAgentFlow(with: url) == true {
            return nil // Will be handled by the completion handler
        }
        return nil
    }
    
    public func refreshToken(_ refreshToken: String) async throws -> ProviderAuthResult {
        return try await withCheckedThrowingContinuation { continuation in
            guard let issuerURL = URL(string: issuer) else {
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
        currentAuthSession = nil
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