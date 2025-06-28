import Foundation

public enum AuthProviderType: String, CaseIterable, Codable, Sendable {
    case apple = "apple"
    case google = "google"
    case github = "github"
    
    public var displayName: String {
        switch self {
        case .apple:
            return "Apple"
        case .google:
            return "Google"
        case .github:
            return "GitHub"
        }
    }
}