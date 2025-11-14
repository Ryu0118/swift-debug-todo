import Foundation

/// Protocol for creating GitHub issues from todo items.
/// Implement this protocol to define when and how GitHub issues are created.
@MainActor
public protocol GitHubIssueCreatorProtocol: Sendable {
    /// Called when a new todo item is added.
    ///
    /// - Parameter item: The newly created todo item.
    /// - Returns: The created GitHub issue, or nil if no issue was created.
    func onTodoCreated(_ item: TodoItem) async throws -> GitHubIssue?

    /// Manually creates a GitHub issue for a todo item.
    /// This is typically called by user action (e.g., button press).
    ///
    /// - Parameter item: The todo item to create an issue for.
    func createIssue(for item: TodoItem) async throws -> GitHubIssue?
}

/// Represents a GitHub issue.
public struct GitHubIssue: Codable, Sendable {
    public let id: Int
    public let number: Int
    public let title: String
    public let body: String?
    public let htmlUrl: String
    public let state: String

    enum CodingKeys: String, CodingKey {
        case id
        case number
        case title
        case body
        case htmlUrl = "html_url"
        case state
    }
}

/// A no-op implementation that doesn't create any GitHub issues.
@MainActor
public struct NoOpGitHubIssueCreator: GitHubIssueCreatorProtocol {
    public init() {}

    public func onTodoCreated(_ item: TodoItem) async throws -> GitHubIssue? {
        // Do nothing
        return nil
    }

    public func createIssue(for item: TodoItem) async throws -> GitHubIssue? {
        nil
    }
}
