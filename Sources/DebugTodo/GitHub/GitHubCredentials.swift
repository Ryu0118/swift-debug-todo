import Foundation
import Logging
import Observation

/// Protocol for storing GitHub access tokens.
public protocol GitHubTokenStorage: Sendable {
    func saveToken(_ token: String) async throws
    func loadToken() async throws -> String?
    func deleteToken() async throws
}

/// Keychain-based token storage (recommended for security).
public struct KeychainTokenStorage: GitHubTokenStorage {
    private let keychain: KeychainStorage
    private let key: String

    public init(
        service: String = "com.debugtodo.github",
        key: String = "accessToken"
    ) {
        self.keychain = KeychainStorage(service: service)
        self.key = key
    }

    public func saveToken(_ token: String) async throws {
        try await keychain.save(token, forKey: key)
    }

    public func loadToken() async throws -> String? {
        try await keychain.load(forKey: key)
    }

    public func deleteToken() async throws {
        try await keychain.delete(forKey: key)
    }
}

/// Manages GitHub credentials using Personal Access Token.
@Observable
@MainActor
public final class GitHubCredentials {
    public private(set) var accessToken: String?
    public private(set) var isAuthenticated: Bool = false
    public var personalAccessToken: String

    private let storage: GitHubTokenStorage

    /// Creates new GitHub credentials.
    ///
    /// - Parameter storage: Storage for persisting the access token. Defaults to Keychain.
    public init(storage: GitHubTokenStorage = KeychainTokenStorage()) {
        self.personalAccessToken = ""
        self.storage = storage

        // Load token from storage
        Task {
            do {
                if let token = try await storage.loadToken() {
                    await MainActor.run {
                        self.personalAccessToken = token
                        self.accessToken = token
                        self.isAuthenticated = true
                    }
                }
            } catch {
                logger.error("Failed to load token from storage", metadata: ["error": "\(error)"])
            }
        }
    }

    /// Saves the current Personal Access Token to Keychain.
    public func saveToken() async throws {
        guard !personalAccessToken.isEmpty else {
            throw GitHubAuthError.emptyToken
        }

        try await storage.saveToken(personalAccessToken)
        accessToken = personalAccessToken
        isAuthenticated = true
    }

    /// Signs out and clears the stored token.
    public func signOut() {
        personalAccessToken = ""
        accessToken = nil
        isAuthenticated = false
        Task {
            do {
                try await storage.deleteToken()
            } catch {
                logger.error("Failed to delete token", metadata: ["error": "\(error)"])
            }
        }
    }
}

/// Errors that can occur during GitHub authentication.
public enum GitHubAuthError: LocalizedError {
    case emptyToken

    public var errorDescription: String? {
        switch self {
        case .emptyToken:
            return "Personal Access Token cannot be empty"
        }
    }
}
