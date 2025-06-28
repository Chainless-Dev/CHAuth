import Testing
import Foundation
@testable import CHAuth
#if os(iOS)
import UIKit
#endif

@Test("iOS compilation compatibility")
func testIOSCompilation() async throws {
    // Test that iOS-specific code compiles correctly
    #if os(iOS)
    await MainActor.run {
        let appleProvider = AppleAuthProvider()
        #expect(appleProvider.providerType == .apple)
        #expect(appleProvider.redirectScheme == nil)
        #expect(appleProvider.requiredScopes.isEmpty)
    }
    #endif
    
    // This test should pass on all platforms
    #expect(Bool(true))
}

@Test("Platform-specific provider initialization")
func testPlatformProviders() async throws {
    await MainActor.run {
        // Apple provider should work on all platforms
        let appleProvider = AppleAuthProvider()
        #expect(appleProvider.providerType == .apple)
        
        // Google provider should work on all platforms
        let googleProvider = GoogleAuthProvider(
            clientID: "test-client-id",
            redirectScheme: "com.test.app"
        )
        #expect(googleProvider.providerType == .google)
        #expect(googleProvider.redirectScheme == "com.test.app")
    }
}

@Test("UI components compilation")
func testUIComponents() async throws {
    // Test that SwiftUI components compile correctly
    await MainActor.run {
        let _ = AuthButton(provider: .apple) {
            // Mock action
        }
    }
    
    // Verify the test completed successfully
    #expect(Bool(true))
}