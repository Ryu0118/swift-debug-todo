import Foundation
import Observation

/// A service that manages GitHub integration for TodoListView.
///
/// This service provides a simple interface for GitHub integration, handling
/// authentication, configuration, and issue creation internally.
///
/// Example usage:
/// ```swift
/// struct ContentView: View {
///     @State private var service = GitHubService()
///
///     var body: some View {
///         TodoListView(
///             storage: UserDefaultsStorage(),
///             issueCreator: service.issueCreator
///         )
///         .toolbar {
///             ToolbarItem {
///                 NavigationLink {
///                     GitHubSettingsView(for: service)
///                 } label: {
///                     Image(systemName: "gearshape")
///                 }
///             }
///         }
///     }
/// }
/// ```
@Observable
@MainActor
public final class GitHubService {
    /// The GitHub credentials.
    public var credentials: GitHubCredentials

    /// The GitHub repository settings.
    public var repositorySettings: GitHubRepositorySettings

    /// The issue creator for TodoListView.
    public let issueCreator: GitHubIssueCreator

    private let repositorySettingsStorage: GitHubRepositorySettingsStorage

    /// Creates a new GitHub service.
    ///
    /// - Parameters:
    ///   - tokenStorage: Storage for the access token. Defaults to Keychain.
    ///   - repositorySettingsStorage: Storage for the repository settings. Defaults to Keychain.
    public init(
        tokenStorage: GitHubTokenStorage = KeychainTokenStorage(),
        repositorySettingsStorage: GitHubRepositorySettingsStorage = KeychainRepositorySettingsStorage()
    ) {
        // Load repository settings from storage
        let loadedSettings: GitHubRepositorySettings
        do {
            loadedSettings = try repositorySettingsStorage.load()
        } catch {
            loadedSettings = GitHubRepositorySettings()
        }

        let credentials = GitHubCredentials(storage: tokenStorage)

        self.credentials = credentials
        self.repositorySettings = loadedSettings
        self.repositorySettingsStorage = repositorySettingsStorage
        self.issueCreator = GitHubIssueCreator(
            repositorySettings: loadedSettings,
            credentials: credentials
        )
    }

    /// Saves the current repository settings to storage.
    public func saveRepositorySettings() throws {
        try repositorySettingsStorage.save(repositorySettings)
    }
}
