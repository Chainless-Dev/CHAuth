import Foundation

public final class DefaultUserProfileStandardizer: UserProfileStandardizer {
    public init() {}
    
    public func standardize(from provider: ProviderAuthResult, and service: AuthResponse) -> User {
        let providerUserInfo = provider.userInfo
        let serviceUser = service.user
        
        // Extract names based on provider
        let (givenName, familyName, fullName) = extractNames(
            from: providerUserInfo,
            provider: provider.provider,
            serviceUser: serviceUser
        )
        
        // Extract email
        let email = extractEmail(from: providerUserInfo, serviceUser: serviceUser)
        
        // Extract avatar URL
        let avatarURL = extractAvatarURL(from: providerUserInfo, serviceUser: serviceUser)
        
        return User(
            id: serviceUser.id,
            email: email,
            fullName: fullName,
            givenName: givenName,
            familyName: familyName,
            avatarURL: avatarURL,
            provider: provider.provider,
            createdAt: serviceUser.createdAt,
            lastSignInAt: serviceUser.lastSignInAt
        )
    }
    
    private func extractNames(
        from userInfo: [String: AnySendableValue],
        provider: AuthProviderType,
        serviceUser: ServiceUser
    ) -> (givenName: String?, familyName: String?, fullName: String?) {
        var givenName: String?
        var familyName: String?
        var fullName: String?
        
        switch provider {
        case .apple:
            givenName = userInfo["given_name"]?.stringValue
            familyName = userInfo["family_name"]?.stringValue
            fullName = userInfo["full_name"]?.stringValue
            
        case .google:
            givenName = userInfo["given_name"]?.stringValue
            familyName = userInfo["family_name"]?.stringValue
            fullName = userInfo["name"]?.stringValue
            
        case .github:
            fullName = userInfo["name"]?.stringValue
            // GitHub doesn't separate first/last names by default
        }
        
        // Fallback to service user data
        if fullName == nil {
            fullName = serviceUser.fullName
        }
        
        // If we have given and family names but no full name, construct it
        if fullName == nil, let given = givenName, let family = familyName {
            fullName = "\(given) \(family)"
        }
        
        return (givenName, familyName, fullName)
    }
    
    private func extractEmail(from userInfo: [String: AnySendableValue], serviceUser: ServiceUser) -> String? {
        // Try provider user info first
        if let email = userInfo["email"]?.stringValue {
            return email
        }
        
        // Fallback to service user
        return serviceUser.email
    }
    
    private func extractAvatarURL(from userInfo: [String: AnySendableValue], serviceUser: ServiceUser) -> URL? {
        // Try provider user info first
        if let avatarURLString = userInfo["picture"]?.stringValue ?? userInfo["avatar_url"]?.stringValue {
            return URL(string: avatarURLString)
        }
        
        // Fallback to service user
        return serviceUser.avatarURL
    }
}