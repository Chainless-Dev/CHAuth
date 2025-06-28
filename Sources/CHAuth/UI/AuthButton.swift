import SwiftUI

public struct AuthButton: View {
    let provider: AuthProviderType
    let action: () -> Void
    
    public init(provider: AuthProviderType, action: @escaping () -> Void) {
        self.provider = provider
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: provider.systemImageName)
                    .foregroundColor(provider.iconColor)
                
                Text("Continue with \(provider.displayName)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(provider.textColor)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(provider.backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(provider.borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension AuthProviderType {
    var systemImageName: String {
        switch self {
        case .apple:
            return "applelogo"
        case .google:
            return "globe"
        case .github:
            return "chevron.left.forwardslash.chevron.right"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .apple:
            return Color.black
        case .google:
            return Color.white
        case .github:
            return Color.black
        }
    }
    
    var textColor: Color {
        switch self {
        case .apple:
            return Color.white
        case .google:
            return Color.black
        case .github:
            return Color.white
        }
    }
    
    var iconColor: Color {
        switch self {
        case .apple:
            return Color.white
        case .google:
            return Color.blue
        case .github:
            return Color.white
        }
    }
    
    var borderColor: Color {
        switch self {
        case .apple:
            return Color.clear
        case .google:
            return Color.gray.opacity(0.3)
        case .github:
            return Color.clear
        }
    }
}