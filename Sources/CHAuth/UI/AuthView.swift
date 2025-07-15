import SwiftUI

public struct AuthView<Content: View>: View {
    @EnvironmentObject private var authManager: AuthManager
    let providers: [AuthProviderType]
    let content: () -> Content

    public init(
        providers: [AuthProviderType] = [.apple, .google],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.providers = providers
        self.content = content
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            content()

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
    AuthView(providers: [.apple, .google]) {
        VStack {
            Spacer()
            Text("Hello app")
                .font(.largeTitle)
            Spacer()
        }
    }
    .environmentObject(AuthManager.shared)
}

extension Color {
    /// Creates a color that adapts to light and dark mode
    /// - Parameters:
    ///   - light: Color for light mode
    ///   - dark: Color for dark mode
    public init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }

    /// Creates a color from hex values for light and dark mode
    /// - Parameters:
    ///   - lightHex: Hex string for light mode (e.g., "#FFFFFF" or "FFFFFF")
    ///   - darkHex: Hex string for dark mode
    public init(lightHex: String, darkHex: String) {
        self.init(
            light: Color(hex: lightHex),
            dark: Color(hex: darkHex)
        )
    }
}

extension Color {
    /// Creates a color from a hex string
    /// - Parameter hex: Hex string (e.g., "#FFFFFF", "FFFFFF", "#FFF", "FFF")
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
