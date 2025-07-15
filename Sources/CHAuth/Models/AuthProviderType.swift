import Foundation

public enum AuthProviderType: String, CaseIterable, Codable, Sendable {
    case apple = "apple"
    case google = "google"
    
    public var displayName: String {
        switch self {
        case .apple:
            return "Apple"
        case .google:
            return "Google"
        }
    }
}
