// CHAuth - A protocol-oriented authentication framework for Swift/SwiftUI
// Copyright (c) 2024 CHAuth. All rights reserved.

import Foundation

// Re-export all public types
public typealias CHUser = User
public typealias CHAuthState = AuthState
public typealias CHAuthError = AuthError
public typealias CHAuthProviderType = AuthProviderType
public typealias CHProviderAuthResult = ProviderAuthResult
public typealias CHAuthResponse = AuthResponse
public typealias CHServiceUser = ServiceUser
public typealias CHAuthTokens = AuthTokens

// Re-export protocols
public typealias CHAuthProvider = AuthProvider
public typealias CHAuthService = AuthService
public typealias CHSessionManager = SessionManager
public typealias CHAuthCoordinator = AuthCoordinator
public typealias CHUserProfileStandardizer = UserProfileStandardizer

// Re-export manager
public typealias CHAuthManager = AuthManager

// Re-export implementations
public typealias CHDefaultAuthCoordinator = DefaultAuthCoordinator
public typealias CHDefaultUserProfileStandardizer = DefaultUserProfileStandardizer
public typealias CHKeychainSessionManager = KeychainSessionManager

// Re-export providers
public typealias CHAppleAuthProvider = AppleAuthProvider
public typealias CHGoogleAuthProvider = GoogleAuthProvider

// Re-export utilities
public typealias CHAuthURLHandler = AuthURLHandler

// Re-export UI components
public typealias CHAuthButton = AuthButton
public typealias CHAuthView = AuthView
public typealias CHUserProfileView = UserProfileView

// MARK: - Configuration
public struct CHAuthConfiguration: @unchecked Sendable {
    public let service: AuthService
    public let providers: [AuthProvider]
    public let sessionManager: SessionManager?
    public let coordinator: AuthCoordinator?
    public let options: CHAuthOptions
    
    public init(
        service: AuthService,
        providers: [AuthProvider],
        sessionManager: SessionManager? = nil,
        coordinator: AuthCoordinator? = nil,
        options: CHAuthOptions = CHAuthOptions()
    ) {
        self.service = service
        self.providers = providers
        self.sessionManager = sessionManager
        self.coordinator = coordinator
        self.options = options
    }
}

public struct CHAuthOptions: Sendable {
    public let automaticTokenRefresh: Bool
    public let sessionPersistence: Bool
    public let biometricProtection: Bool
    public let debugLogging: Bool
    
    public init(
        automaticTokenRefresh: Bool = true,
        sessionPersistence: Bool = true,
        biometricProtection: Bool = false,
        debugLogging: Bool = false
    ) {
        self.automaticTokenRefresh = automaticTokenRefresh
        self.sessionPersistence = sessionPersistence
        self.biometricProtection = biometricProtection
        self.debugLogging = debugLogging
    }
}

// MARK: - Convenience Extensions
public extension AuthManager {
    static func configure(with configuration: CHAuthConfiguration) {
        AuthManager.configure(
            service: configuration.service,
            providers: configuration.providers,
            sessionManager: configuration.sessionManager,
            coordinator: configuration.coordinator
        )
    }
}