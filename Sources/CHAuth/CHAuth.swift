// CHAuth - A protocol-oriented authentication framework for Swift/SwiftUI
// Copyright (c) 2024 CHAuth. All rights reserved.

import Foundation

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
