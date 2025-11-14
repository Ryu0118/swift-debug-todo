import Foundation
import Observation

/// Repository settings for GitHub integration.
@Observable
public final class GitHubRepositorySettings {
    /// The repository owner (username or organization).
    public var owner: String

    /// The repository name.
    public var repo: String

    /// Whether to show a confirmation alert before creating GitHub issues.
    public var showConfirmationAlert: Bool

    /// Creates new GitHub repository settings.
    ///
    /// - Parameters:
    ///   - owner: The repository owner.
    ///   - repo: The repository name.
    ///   - showConfirmationAlert: Whether to show a confirmation alert before creating issues.
    public init(owner: String = "", repo: String = "", showConfirmationAlert: Bool = true) {
        self.owner = owner
        self.repo = repo
        self.showConfirmationAlert = showConfirmationAlert
    }

    /// Returns `true` if the settings are valid.
    public var isValid: Bool {
        !owner.isEmpty && !repo.isEmpty
    }

    /// Returns the full repository identifier (owner/repo).
    public var fullName: String {
        "\(owner)/\(repo)"
    }
}

/// Storage for GitHub repository settings.
public protocol GitHubRepositorySettingsStorage: Sendable {
    func save(_ settings: GitHubRepositorySettings) throws
    func load() throws -> GitHubRepositorySettings
}

/// Keychain-based repository settings storage (recommended for security).
public struct KeychainRepositorySettingsStorage: GitHubRepositorySettingsStorage {
    private let keychain: KeychainStorage
    private let ownerKey: String
    private let repoKey: String
    private let showConfirmationAlertKey: String

    public init(
        service: String = "com.debugtodo.github",
        ownerKey: String = "owner",
        repoKey: String = "repo",
        showConfirmationAlertKey: String = "showConfirmationAlert"
    ) {
        self.keychain = KeychainStorage(service: service)
        self.ownerKey = ownerKey
        self.repoKey = repoKey
        self.showConfirmationAlertKey = showConfirmationAlertKey
    }

    public func save(_ settings: GitHubRepositorySettings) throws {
        try keychain.save(settings.owner, forKey: ownerKey)
        try keychain.save(settings.repo, forKey: repoKey)
        try keychain.save(
            settings.showConfirmationAlert ? "true" : "false", forKey: showConfirmationAlertKey)
    }

    public func load() throws -> GitHubRepositorySettings {
        let owner = try keychain.load(forKey: ownerKey) ?? ""
        let repo = try keychain.load(forKey: repoKey) ?? ""
        let showConfirmationAlert =
            (try? keychain.load(forKey: showConfirmationAlertKey)) != "false"  // Default true
        return GitHubRepositorySettings(
            owner: owner,
            repo: repo,
            showConfirmationAlert: showConfirmationAlert
        )
    }
}
