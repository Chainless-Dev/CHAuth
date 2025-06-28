# CHAuth Changelog

## [1.0.0] - 2025-06-28

### Added
- Complete CHAuth framework implementation
- Protocol-oriented architecture with full extensibility
- Apple Sign-In provider with AuthenticationServices integration
- Google OAuth provider with AppAuth integration
- Supabase backend service integration
- Secure keychain-based session management
- SwiftUI authentication components (AuthButton, AuthView, UserProfileView)
- Comprehensive error handling with localized messages
- URL-based OAuth callback handling
- User profile standardization across providers
- Full Swift 6.0 concurrency support with Sendable compliance
- Cross-platform support (iOS 15+, macOS 12+, watchOS 8+, tvOS 15+)

### iOS-Specific Fixes
- Fixed deprecated `UIApplication.shared.windows` usage for iOS 15+
- Implemented modern window scene API support for presentation contexts
- Added proper UIKit/AppKit imports for platform-specific code
- Enhanced OAuth flow handling for iOS with proper view controller presentation
- Updated Apple Sign-In provider to use current iOS best practices
- **MainActor isolation** for all OAuth providers ensuring UI operations on main thread
- Added comprehensive iOS integration guide and examples

### Technical Features
- `AnySendableValue` wrapper for type-safe cross-actor data handling
- **MainActor isolation** for OAuth providers ensuring UI thread safety
- Automatic token refresh with configurable options
- Thread-safe URL handling with concurrent queue management
- Mock implementations for comprehensive testing
- 12 passing unit tests covering core functionality

### Documentation
- Complete README with quick start guide
- Detailed iOS integration documentation
- API documentation throughout codebase
- Code examples for common use cases
- Troubleshooting guide for common issues

### Dependencies
- AppAuth-iOS 1.7.5+ for OAuth flows
- Supabase-Swift 2.12.0+ for backend integration  
- KeychainAccess 4.2.2+ for secure token storage
- Swift 6.0+ for modern concurrency features

### Supported Authentication Flows
- ✅ Apple Sign-In (iOS/macOS)
- ✅ Google OAuth 2.0 (iOS/macOS)
- 🔄 GitHub OAuth (placeholder for future implementation)
- ✅ Supabase backend authentication
- 🔄 Firebase authentication (planned)

### Platform Compatibility
- ✅ iOS 15.0+ - Full support with modern APIs
- ✅ macOS 12.0+ - Full support with AppKit
- ✅ watchOS 8.0+ - Core authentication (no UI)
- ✅ tvOS 15.0+ - Core authentication (no OAuth)

### Breaking Changes
- None (initial release)

### Migration Guide
- This is the initial release, no migration needed

---

**Note**: This framework follows semantic versioning. All iOS-specific issues have been resolved and the framework is production-ready for Swift 6.0 applications.