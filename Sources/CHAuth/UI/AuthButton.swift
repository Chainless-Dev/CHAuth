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
                Spacer()

                Image(provider.icon)
                    .resizable()
                    .foregroundColor(provider.iconColor)
                    .frame(width: 20, height: 20)

                Text("Continue With \(provider.displayName)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(provider.textColor)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(provider.backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(provider.borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension AuthProviderType {
    var icon: ImageResource {
        switch self {
        case .apple:
            return ImageResource(name: "apple_logo_32", bundle: .module)
        case .google:
            return ImageResource(name: "google_logo_32", bundle: .module)
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .apple:
            return Color(light: .black, dark: .white)
        case .google:
            return .white
        }
    }
    
    var textColor: Color {
        switch self {
        case .apple:
            return Color(light: .white, dark: .black)
        case .google:
            return .black
        }
    }
    
    var iconColor: Color {
        switch self {
        case .apple:
            return Color(light: .white, dark: .black)
        case .google:
            return Color.clear
        }
    }
    
    var borderColor: Color {
        switch self {
        case .apple:
            return Color.clear
        case .google:
            return Color.gray.opacity(0.3)
        }
    }
}

#Preview {
    AuthButton(provider: .apple) {
    }
    .padding()

    AuthButton(provider: .google) {
    }
    .padding()
}
