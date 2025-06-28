import Foundation

public struct User: Codable, Identifiable, Sendable {
    public let id: String
    public let email: String?
    public let fullName: String?
    public let givenName: String?
    public let familyName: String?
    public let avatarURL: URL?
    public let provider: AuthProviderType
    public let createdAt: Date
    public let lastSignInAt: Date
    
    public var displayName: String {
        fullName ?? email ?? "Unknown User"
    }
    
    public init(
        id: String,
        email: String? = nil,
        fullName: String? = nil,
        givenName: String? = nil,
        familyName: String? = nil,
        avatarURL: URL? = nil,
        provider: AuthProviderType,
        createdAt: Date,
        lastSignInAt: Date
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.givenName = givenName
        self.familyName = familyName
        self.avatarURL = avatarURL
        self.provider = provider
        self.createdAt = createdAt
        self.lastSignInAt = lastSignInAt
    }
}