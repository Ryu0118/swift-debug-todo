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
    public var issueCreator: GitHubIssueCreator

    private let repositorySettingsStorage: GitHubRepositorySettingsStorage

    /// Creates a new GitHub service.
    ///
    /// - Parameters:
    ///   - tokenStorage: Storage for the access token. Defaults to Keychain.
    ///   - repositorySettingsStorage: Storage for the repository settings. Defaults to Keychain.
    public init(
        tokenStorage: GitHubTokenStorage = KeychainTokenStorage(),
        repositorySettingsStorage: GitHubRepositorySettingsStorage =
            KeychainRepositorySettingsStorage()
    ) {
        let credentials = GitHubCredentials(storage: tokenStorage)
        let defaultSettings = GitHubRepositorySettings()

        self.credentials = credentials
        self.repositorySettings = defaultSettings
        self.repositorySettingsStorage = repositorySettingsStorage

        // Temporary initialization - will be updated after self is fully initialized
        self.issueCreator = GitHubIssueCreator(
            getRepositorySettings: { defaultSettings },
            credentials: credentials
        )

        // Update the closure to capture self properly
        self.issueCreator = GitHubIssueCreator(
            getRepositorySettings: { [unowned self] in
                self.repositorySettings
            },
            credentials: credentials
        )

        // Load repository settings from storage asynchronously
        Task {
            do {
                let loadedSettings = try await repositorySettingsStorage.load()
                await MainActor.run {
                    self.repositorySettings = loadedSettings
                }
            } catch {
                // Use default settings on error
            }
        }
    }

    /// Saves the current repository settings to storage.
    public func saveRepositorySettings() async throws {
        try await repositorySettingsStorage.save(repositorySettings)
    }
}
