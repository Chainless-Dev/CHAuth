import Foundation

public struct AuthResponse: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let user: ServiceUser
    public let expiresAt: Date
    public let tokenType: String
    
    public init(
        accessToken: String,
        refreshToken: String,
        user: ServiceUser,
        expiresAt: Date,
        tokenType: String = "Bearer"
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.user = user
        self.expiresAt = expiresAt
        self.tokenType = tokenType
    }
}

public struct ServiceUser: Codable, Sendable {
    public let id: String
    public let email: String?
    public let fullName: String?
    public let avatarURL: URL?
    public let createdAt: Date
    public let lastSignInAt: Date
    
    public init(
        id: String,
        email: String? = nil,
        fullName: String? = nil,
        avatarURL: URL? = nil,
        createdAt: Date,
        lastSignInAt: Date
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.avatarURL = avatarURL
        self.createdAt = createdAt
        self.lastSignInAt = lastSignInAt
    }
}