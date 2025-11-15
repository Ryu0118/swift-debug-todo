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
    /// The saved access token (Single Source of Truth)
    public private(set) var accessToken: String?

    /// Whether the user is authenticated
    public private(set) var isAuthenticated: Bool = false

    private let storage: GitHubTokenStorage

    /// Creates new GitHub credentials.
    ///
    /// - Parameter storage: Storage for persisting the access token. Defaults to Keychain.
    public init(storage: GitHubTokenStorage = KeychainTokenStorage()) {
        self.storage = storage

        // Load token from storage
        Task {
            do {
                if let token = try await storage.loadToken() {
                    await MainActor.run {
                        self.accessToken = token
                        self.isAuthenticated = true
                    }
                }
            } catch {
                logger.error("Failed to load token from storage", metadata: ["error": "\(error)"])
            }
        }
    }

    /// Saves the given Personal Access Token to storage.
    ///
    /// - Parameter token: The token to save.
    public func saveToken(_ token: String) async throws {
        guard !token.isEmpty else {
            throw GitHubAuthError.emptyToken
        }

        try await storage.saveToken(token)
        accessToken = token
        isAuthenticated = true
    }

    /// Signs out and clears the stored token.
    public func signOut() async {
        accessToken = nil
        isAuthenticated = false
        do {
            try await storage.deleteToken()
        } catch {
            logger.error("Failed to delete token", metadata: ["error": "\(error)"])
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
