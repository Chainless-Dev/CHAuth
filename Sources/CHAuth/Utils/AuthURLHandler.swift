import Foundation
import CHLogger

public final class AuthURLHandler: @unchecked Sendable {
    public static let shared = AuthURLHandler()
    
    private var pendingProviders: [String: AuthProvider] = [:]
    private var activeFlows: [String: UUID] = [:]
    private let queue = DispatchQueue(label: "com.chauth.urlhandler", attributes: .concurrent)
    
    private init() {}
    
    public func registerProvider(_ provider: AuthProvider, for scheme: String, flowID: UUID) {
        Task { @MainActor in
            let providerTypeName = provider.providerType.rawValue
            log.debug("URLHandler: Registering provider \(providerTypeName) for scheme: \(scheme)")
        }
        queue.async(flags: .barrier) {
            self.pendingProviders[scheme] = provider
            self.activeFlows[scheme] = flowID
        }
    }
    
    public func handleURL(_ url: URL) async -> Bool {
        log.info("URLHandler: Handling URL: \(url.absoluteString)")
        
        guard let scheme = url.scheme else {
            log.warning("URLHandler: No scheme found in URL")
            return false
        }
        
        let provider = queue.sync { pendingProviders[scheme] }
        guard let provider = provider else {
            log.warning("URLHandler: No provider registered for scheme: \(scheme)")
            return false
        }
        
        defer { clearPendingProvider(for: scheme) }
        
        // Handle the callback with the MainActor provider
        do {
            let providerTypeName = await provider.providerType.rawValue
            log.debug("URLHandler: Calling provider \(providerTypeName) to handle callback")
            let _ = try await provider.handleCallback(url: url)
            log.info("URLHandler: URL successfully handled by provider \(providerTypeName)")
            return true
        } catch {
            let providerTypeName = await provider.providerType.rawValue
            log.error("URLHandler: Provider \(providerTypeName) failed to handle URL: \(error.localizedDescription)")
            return false
        }
    }
    
    public func clearPendingProvider(for scheme: String) {
        log.debug("URLHandler: Clearing pending provider for scheme: \(scheme)")
        queue.async(flags: .barrier) {
            self.pendingProviders.removeValue(forKey: scheme)
            self.activeFlows.removeValue(forKey: scheme)
        }
    }
    
    public func clearAllPendingProviders() {
        log.info("URLHandler: Clearing all pending providers")
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
