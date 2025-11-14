import Foundation
import Logging
import Observation

/// Protocol for storing GitHub access tokens.
public protocol GitHubTokenStorage: Sendable {
    func saveToken(_ token: String) throws
    func loadToken() throws -> String?
    func deleteToken() throws
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

    public func saveToken(_ token: String) throws {
        try keychain.save(token, forKey: key)
    }

    public func loadToken() throws -> String? {
        try keychain.load(forKey: key)
    }

    public func deleteToken() throws {
        try keychain.delete(forKey: key)
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
        do {
            if let token = try storage.loadToken() {
                self.personalAccessToken = token
                self.accessToken = token
                self.isAuthenticated = true
            }
        } catch {
            logger.error("Failed to load token from storage", metadata: ["error": "\(error)"])
        }
    }

    /// Saves the current Personal Access Token to Keychain.
    public func saveToken() throws {
        guard !personalAccessToken.isEmpty else {
            throw GitHubAuthError.emptyToken
        }

        try storage.saveToken(personalAccessToken)
        accessToken = personalAccessToken
        isAuthenticated = true
    }

    /// Signs out and clears the stored token.
    public func signOut() {
        personalAccessToken = ""
        accessToken = nil
        isAuthenticated = false
        do {
            try storage.deleteToken()
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
