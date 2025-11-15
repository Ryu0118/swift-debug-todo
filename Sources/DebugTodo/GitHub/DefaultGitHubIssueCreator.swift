import Foundation

/// Default implementation that creates GitHub issues when new todos are created.
@MainActor
public final class GitHubIssueCreator: GitHubIssueCreatorProtocol, @unchecked Sendable {
    private let apiClient = GitHubAPIClient()
    private let getRepositorySettings: () -> GitHubRepositorySettings
    private let credentials: GitHubCredentials

    /// Creates a new GitHub issue creator.
    ///
    /// - Parameters:
    ///   - getRepositorySettings: Closure that returns the current repository settings.
    ///   - credentials: The GitHub credentials.
    public init(
        getRepositorySettings: @escaping () -> GitHubRepositorySettings,
        credentials: GitHubCredentials
    ) {
        self.getRepositorySettings = getRepositorySettings
        self.credentials = credentials
    }

    public func onTodoCreated(_ item: TodoItem) async throws -> GitHubIssue? {
        return try await createIssue(for: item)
    }

    public func createIssue(for item: TodoItem) async throws -> GitHubIssue? {
        let repositorySettings = getRepositorySettings()

        guard repositorySettings.isValid else {
            throw GitHubIssueCreatorError.invalidConfiguration
        }

        guard let token = credentials.accessToken else {
            throw GitHubIssueCreatorError.notAuthenticated
        }

        await apiClient.setAccessToken(token)

        let body = item.detail.isEmpty ? nil : item.detail
        let issue = try await apiClient.createIssue(
            owner: repositorySettings.owner,
            repo: repositorySettings.repo,
            title: item.title,
            body: body
        )

        return issue
    }

    /// Updates the state of a GitHub issue.
    ///
    /// - Parameters:
    ///   - owner: The repository owner.
    ///   - repo: The repository name.
    ///   - issueNumber: The issue number.
    ///   - state: The new state ("open" or "closed").
    ///   - stateReason: The reason for the state change (optional).
    /// - Returns: The updated GitHub issue.
    public func updateIssueState(
        owner: String,
        repo: String,
        issueNumber: Int,
        state: String,
        stateReason: IssueStateReason?
    ) async throws -> GitHubIssue {
        guard let token = credentials.accessToken else {
            throw GitHubIssueCreatorError.notAuthenticated
        }

        await apiClient.setAccessToken(token)

        let issue = try await apiClient.updateIssue(
            owner: owner,
            repo: repo,
            issueNumber: issueNumber,
            state: state,
            stateReason: stateReason
        )

        return issue
    }

    /// Updates the content of a GitHub issue.
    ///
    /// - Parameters:
    ///   - owner: The repository owner.
    ///   - repo: The repository name.
    ///   - issueNumber: The issue number.
    ///   - title: The new title.
    ///   - body: The new body (optional).
    /// - Returns: The updated GitHub issue.
    public func updateIssueContent(
        owner: String,
        repo: String,
        issueNumber: Int,
        title: String,
        body: String?
    ) async throws -> GitHubIssue {
        guard let token = credentials.accessToken else {
            throw GitHubIssueCreatorError.notAuthenticated
        }

        await apiClient.setAccessToken(token)

        let issue = try await apiClient.updateIssue(
            owner: owner,
            repo: repo,
            issueNumber: issueNumber,
            title: title,
            body: body
        )

        return issue
    }

    /// Gets a GitHub issue by its number.
    ///
    /// - Parameters:
    ///   - owner: The repository owner.
    ///   - repo: The repository name.
    ///   - issueNumber: The issue number.
    /// - Returns: The GitHub issue.
    public func getIssue(
        owner: String,
        repo: String,
        issueNumber: Int
    ) async throws -> GitHubIssue {
        guard let token = credentials.accessToken else {
            throw GitHubIssueCreatorError.notAuthenticated
        }

        await apiClient.setAccessToken(token)

        let issue = try await apiClient.getIssue(
            owner: owner,
            repo: repo,
            issueNumber: issueNumber
        )

        return issue
    }
}

/// Errors that can occur when creating GitHub issues.
public enum GitHubIssueCreatorError: LocalizedError {
    case invalidConfiguration
    case notAuthenticated

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "GitHub configuration is invalid. Please set owner and repo."
        case .notAuthenticated:
            return "Not authenticated with GitHub. Please sign in first."
        }
    }
}
