import Foundation

public struct ProviderAuthResult: Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let idToken: String?
    public let expiresAt: Date?
    public let scope: String?
    public let userInfo: [String: AnySendableValue]
    public let provider: AuthProviderType
    
    public init(
        accessToken: String,
        refreshToken: String? = nil,
        idToken: String? = nil,
        expiresAt: Date? = nil,
        scope: String? = nil,
        userInfo: [String: AnySendableValue] = [:],
        provider: AuthProviderType
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.expiresAt = expiresAt
        self.scope = scope
        self.userInfo = userInfo
        self.provider = provider
    }
}