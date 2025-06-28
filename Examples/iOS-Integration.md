# iOS Integration Guide for CHAuth

## Prerequisites

- iOS 15.0+
- Xcode 16.0+
- Swift 6.0+

## Setup

### 1. Add CHAuth to your iOS project

In Xcode, go to File → Add Package Dependencies and add:
```
https://github.com/your-repo/CHAuth.git
```

### 2. Configure URL Schemes (for OAuth providers)

In your `Info.plist`, add URL schemes for OAuth callbacks:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.yourapp.oauth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.yourapp.auth</string>
        </array>
    </dict>
</array>
```

### 3. Configure CHAuth in your App.swift

```swift
import SwiftUI
import CHAuth

@main
struct MyApp: App {
    
    init() {
        configureCHAuth()
    }
    
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
    
    private func configureCHAuth() {
        // Configure Apple provider
        let appleProvider = AppleAuthProvider()
        
        // Configure Google provider (optional)
        let googleProvider = GoogleAuthProvider(
            clientID: "your-google-client-id.apps.googleusercontent.com",
            redirectScheme: "com.yourapp.auth"
        )
        
        // Configure Supabase service
        let supabaseClient = SupabaseClient(
            supabaseURL: URL(string: "https://your-project.supabase.co")!,
            supabaseKey: "your-anon-key"
        )
        let authService = SupabaseAuthService(supabase: supabaseClient)
        
        // Configure CHAuth
        AuthManager.configure(
            service: authService,
            providers: [appleProvider, googleProvider]
        )
    }
}
```

### 4. Create your main ContentView

```swift
import SwiftUI
import CHAuth

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        NavigationView {
            Group {
                if authManager.isAuthenticated, let user = authManager.currentUser {
                    // User is signed in
                    UserProfileView(user: user)
                } else {
                    // User needs to sign in
                    AuthView(
                        providers: [.apple, .google],
                        title: "Welcome to MyApp",
                        subtitle: "Sign in to continue"
                    )
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle()) // For better iPhone support
    }
}
```

### 5. Handle Authentication State Changes

```swift
struct MainView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var showingAlert = false
    
    var body: some View {
        VStack {
            switch authManager.authState {
            case .unauthenticated:
                AuthView()
                
            case .authenticating(let provider):
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Signing in with \(provider.displayName)...")
                        .padding(.top)
                }
                
            case .authenticated(let user):
                DashboardView(user: user)
                
            case .refreshing:
                VStack {
                    ProgressView()
                    Text("Refreshing session...")
                }
                
            case .error(let error):
                VStack {
                    Text("Authentication Error")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Text(error.localizedDescription)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Try Again") {
                        // Clear error and try again
                        Task {
                            await authManager.refreshSession()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .onChange(of: authManager.lastError) { error in
            showingAlert = error != nil
        }
        .alert("Authentication Error", isPresented: $showingAlert) {
            Button("OK") {
                // Handle error dismissal
            }
        } message: {
            if let error = authManager.lastError {
                Text(error.localizedDescription)
            }
        }
    }
}
```

### 6. Custom Sign-In Buttons

```swift
struct CustomSignInView: View {
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Apple Sign In
            Button(action: {
                Task {
                    await authManager.signIn(with: .apple)
                }
            }) {
                HStack {
                    Image(systemName: "applelogo")
                        .foregroundColor(.white)
                    Text("Continue with Apple")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .cornerRadius(10)
            }
            .disabled(authManager.authState.isAuthenticating)
            
            // Google Sign In
            Button(action: {
                Task {
                    await authManager.signIn(with: .google)
                }
            }) {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                    Text("Continue with Google")
                        .foregroundColor(.black)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(10)
            }
            .disabled(authManager.authState.isAuthenticating)
        }
        .padding()
    }
}
```

## Troubleshooting

### Common Issues

1. **"No presenting view controller available"**
   - Make sure your app has a proper window hierarchy
   - Ensure the authentication is triggered from the main thread

2. **OAuth callbacks not working**
   - Verify URL schemes are correctly configured in Info.plist
   - Check that the redirect scheme matches your provider configuration

3. **Apple Sign In not working**
   - Enable "Sign In with Apple" capability in your Xcode project
   - Make sure your app bundle ID is registered in Apple Developer Console

4. **Google Sign In configuration**
   - Download the GoogleService-Info.plist from Google Cloud Console
   - Add it to your Xcode project
   - Use the REVERSED_CLIENT_ID as your redirect scheme

### Debug Tips

```swift
// Add to your App.swift init() for debugging
AuthManager.configure(
    service: authService,
    providers: providers,
    options: CHAuthOptions(debugLogging: true)
)
```

## Security Considerations

1. **Never expose sensitive keys in client code**
2. **Use proper URL scheme validation**
3. **Implement proper token refresh handling**
4. **Consider adding biometric protection for sensitive operations**

## Testing

For unit testing, CHAuth provides mock implementations:

```swift
import XCTest
@testable import CHAuth

class AuthTests: XCTestCase {
    func testAuthConfiguration() {
        let mockService = MockAuthService()
        let mockProvider = MockAuthProvider()
        
        let config = CHAuthConfiguration(
            service: mockService,
            providers: [mockProvider]
        )
        
        XCTAssertEqual(config.providers.count, 1)
    }
}
```

This integration guide should help you successfully implement CHAuth in your iOS application with proper error handling and user experience considerations.