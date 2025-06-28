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
    
    public func handleURL(_ url: URL) -> Bool {
        return queue.sync {
            guard let scheme = url.scheme else { return false }
            
            guard let provider = pendingProviders[scheme] else { return false }
            
            do {
                let _ = try provider.handleCallback(url: url)
                clearPendingProvider(for: scheme)
                return true
            } catch {
                clearPendingProvider(for: scheme)
                return false
            }
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