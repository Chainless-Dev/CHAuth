import SwiftUI

public struct AuthView: View {
    @EnvironmentObject private var authManager: AuthManager
    let providers: [AuthProviderType]
    let title: String
    let subtitle: String?
    
    public init(
        providers: [AuthProviderType] = [.apple, .google],
        title: String = "Welcome",
        subtitle: String? = "Sign in to continue"
    ) {
        self.providers = providers
        self.title = title
        self.subtitle = subtitle
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
            
            // Authentication Buttons
            VStack(spacing: 12) {
                ForEach(providers, id: \.self) { provider in
                    AuthButton(provider: provider) {
                        Task {
                            await authManager.signIn(with: provider)
                        }
                    }
                    .disabled(authManager.authState.isAuthenticating)
                }
            }
            
            // Loading State
            if authManager.authState.isAuthenticating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Signing in...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            
            // Error State
            if let error = authManager.lastError {
                VStack(spacing: 8) {
                    Text("Sign in failed")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                    
                    Text(error.localizedDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if let recovery = error.recoverySuggestion {
                        Text(recovery)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }
}

extension AuthState {
    var isAuthenticating: Bool {
        switch self {
        case .authenticating, .refreshing:
            return true
        default:
            return false
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager.shared)
}