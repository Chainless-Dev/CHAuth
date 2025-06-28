import SwiftUI

public struct UserProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    let user: User
    
    public init(user: User) {
        self.user = user
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Avatar
            AsyncImage(url: user.avatarURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            }
            
            // User Info
            VStack(spacing: 8) {
                Text(user.displayName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                if let email = user.email {
                    Text(email)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: user.provider.systemImageName)
                        .foregroundColor(user.provider.iconColor)
                    Text("Signed in with \(user.provider.displayName)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Sign Out Button
            Button(action: {
                Task {
                    await authManager.signOut()
                }
            }) {
                Text("Sign Out")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .cornerRadius(8)
            }
            .disabled(authManager.authState.isAuthenticating)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }
}

#Preview {
    UserProfileView(user: User(
        id: "1",
        email: "test@example.com",
        fullName: "John Doe",
        provider: .apple,
        createdAt: Date(),
        lastSignInAt: Date()
    ))
    .environmentObject(AuthManager.shared)
}