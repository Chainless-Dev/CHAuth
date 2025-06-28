# CHAuth - Authentication Framework for Swift

A protocol-oriented authentication framework for Swift/SwiftUI with maximum extensibility and minimal public API surface. CHAuth abstracts OAuth flows, backend authentication services, and session management into a unified, reactive interface.

## Features

- 🏗️ **Protocol-Oriented Architecture**: Every major component is protocol-based for testability and extensibility
- 🔐 **Multiple Auth Providers**: Apple Sign-In, Google OAuth, GitHub (extensible)
- 🎯 **Single Responsibility**: Each component has one clear purpose
- 🔄 **Reactive State Management**: Using Combine publishers for real-time updates
- 🔒 **Secure Token Storage**: Keychain integration for secure token management
- 🎨 **SwiftUI Ready**: Pre-built UI components and seamless integration
- 🧪 **Testable**: Mock implementations for all protocols

## Installation

Add CHAuth to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/your-repo/CHAuth.git", from: "1.0.0")
]
```

## Quick Start

### 1. Configure CHAuth

```swift
import CHAuth
import CHAuthSupabase

// Configure providers
let appleProvider = AppleAuthProvider()
let googleProvider = GoogleAuthProvider(
    clientID: "your-google-client-id",
    redirectScheme: "com.yourapp.auth"
)

// Configure backend service
let supabaseClient = SupabaseClient(
    supabaseURL: URL(string: "https://your-project.supabase.co")!,
    supabaseKey: "your-anon-key"
)
let authService = SupabaseAuthService(supabase: supabaseClient)

// Configure CHAuth
let configuration = CHAuthConfiguration(
    service: authService,
    providers: [appleProvider, googleProvider]
)

AuthManager.configure(with: configuration)
```

### 2. Add URL Handling (for OAuth providers)

In your `App.swift`:

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AuthManager.shared)
                .onOpenURL { url in
                    Task {
                        _ = await AuthURLHandler.shared.handleURL(url)
                    }
                }
        }
    }
}
```

### 3. Use in SwiftUI

```swift
import SwiftUI
import CHAuth

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        Group {
            if authManager.isAuthenticated, let user = authManager.currentUser {
                UserProfileView(user: user)
            } else {
                AuthView(
                    providers: [.apple, .google],
                    title: "Welcome to MyApp",
                    subtitle: "Sign in to continue"
                )
            }
        }
    }
}
```

### 4. Handle Authentication State

```swift
struct MyView: View {
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        VStack {
            switch authManager.authState {
            case .unauthenticated:
                Text("Please sign in")
            case .authenticating(let provider):
                Text("Signing in with \(provider.displayName)...")
            case .authenticated(let user):
                Text("Welcome, \(user.displayName)!")
            case .refreshing:
                Text("Refreshing session...")
            case .error(let error):
                Text("Error: \(error.localizedDescription)")
            }
        }
    }
}
```

## Advanced Usage

### Custom Auth Provider

```swift
class MyCustomProvider: AuthProvider {
    let providerType: AuthProviderType = .custom // Add to enum
    let redirectScheme: String? = "myapp://auth"
    let requiredScopes: [String] = ["profile", "email"]
    
    func authenticate() async throws -> ProviderAuthResult {
        // Implement custom OAuth flow
    }
    
    func handleCallback(url: URL) throws -> ProviderAuthResult? {
        // Handle OAuth callback
    }
    
    // ... other protocol methods
}
```

### Custom Backend Service

```swift
class MyBackendService: AuthService {
    func signIn(with result: ProviderAuthResult) async throws -> AuthResponse {
        // Implement backend authentication
    }
    
    func signOut(token: String) async throws {
        // Implement sign out
    }
    
    // ... other protocol methods
}
```

### Manual Authentication

```swift
// Sign in with specific provider
await authManager.signIn(with: .apple)

// Sign out
await authManager.signOut()

// Refresh session
let success = await authManager.refreshSession()

// Check current state
if authManager.isAuthenticated {
    print("User: \(authManager.currentUser?.displayName ?? "Unknown")")
}
```

## Architecture

CHAuth follows a clean, protocol-oriented architecture:

- **AuthManager**: Central singleton managing authentication state
- **AuthCoordinator**: Orchestrates flows between providers and services
- **AuthProvider**: OAuth provider implementations (Apple, Google, etc.)
- **AuthService**: Backend service integration (Supabase, Firebase, etc.)
- **SessionManager**: Secure token storage and management
- **UserProfileStandardizer**: Normalizes user data across providers

## Requirements

- iOS 15.0+ / macOS 12.0+ / watchOS 8.0+ / tvOS 15.0+
- Swift 6.0+
- Xcode 16.0+

## Platform Support

CHAuth is fully compatible with:
- ✅ **iOS 15.0+** - Full support with modern window scene APIs
- ✅ **macOS 12.0+** - Full support with AppKit integration
- ✅ **watchOS 8.0+** - Core authentication without UI components
- ✅ **tvOS 15.0+** - Core authentication without OAuth flows

### iOS-Specific Features
- Modern window scene support for iOS 15+
- Proper presentation context handling for OAuth flows
- SwiftUI integration with native iOS components
- URL scheme handling for OAuth callbacks

For detailed iOS integration instructions, see [Examples/iOS-Integration.md](Examples/iOS-Integration.md).

## License

CHAuth is available under the MIT license. See the LICENSE file for more info.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.