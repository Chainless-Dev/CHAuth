import Foundation

public final class AuthURLHandler: @unchecked Sendable {
    public static let shared = AuthURLHandler()
    
    private var pendingProviders: [String: AuthProvider] = [:]
    private var activeFlows: [String: UUID] = [:]
    private let queue = DispatchQueue(label: "com.chauth.urlhandler", attributes: .concurrent)
    
    private init() {}
    
    public func registerProvider(_ provider: AuthProvider, for scheme: String, flowID: UUID) {
        queue.async(flags: .barrier) {
            self.pendingProviders[scheme] = provider
            self.activeFlows[scheme] = flowID
        }
    }
    
    public func handleURL(_ url: URL) async -> Bool {
        guard let scheme = url.scheme else { return false }
        
        let provider = queue.sync { pendingProviders[scheme] }
        guard let provider = provider else { return false }
        
        defer { clearPendingProvider(for: scheme) }
        
        // Handle the callback with the MainActor provider
        do {
            let _ = try await provider.handleCallback(url: url)
            return true
        } catch {
            return false
        }
    }
    
    public func clearPendingProvider(for scheme: String) {
        queue.async(flags: .barrier) {
            self.pendingProviders.removeValue(forKey: scheme)
            self.activeFlows.removeValue(forKey: scheme)
        }
    }
    
    public func clearAllPendingProviders() {
        queue.async(flags: .barrier) {
            self.pendingProviders.removeAll()
            self.activeFlows.removeAll()
        }
    }
    
    public func isFlowActive(for scheme: String) -> Bool {
        return queue.sync {
            return pendingProviders[scheme] != nil
        }
    }
}