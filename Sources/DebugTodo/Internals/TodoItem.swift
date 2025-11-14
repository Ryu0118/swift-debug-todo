import Foundation

/// A todo item that represents a task with title, detail, and completion status.
public struct TodoItem: Identifiable, Codable, Equatable, Sendable {
    /// Unique identifier for the todo item.
    public let id: UUID

    /// The title of the todo item.
    public var title: String

    /// Additional details or description for the todo item.
    public var detail: String

    /// Indicates whether the todo item is completed.
    public var isDone: Bool

    /// The date when the todo item was created.
    public var createdAt: Date

    /// The date when the todo item was last updated.
    public var updatedAt: Date

    /// The URL of the linked GitHub issue, if any.
    public var gitHubIssueUrl: String?

    /// Extracts the issue number from the GitHub issue URL.
    public var gitHubIssueNumber: Int? {
        guard let urlString = gitHubIssueUrl,
              let url = URL(string: urlString),
              let lastComponent = url.pathComponents.last,
              let number = Int(lastComponent) else {
            return nil
        }
        return number
    }

    /// Creates a new todo item.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - title: The title of the todo item.
    ///   - detail: Additional details. Defaults to empty string.
    ///   - isDone: Completion status. Defaults to false.
    ///   - createdAt: Creation date. Defaults to current date.
    ///   - updatedAt: Last update date. Defaults to current date.
    ///   - gitHubIssueUrl: The URL of the linked GitHub issue. Defaults to nil.
    public init(
        id: UUID = UUID(),
        title: String,
        detail: String = "",
        isDone: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        gitHubIssueUrl: String? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isDone = isDone
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.gitHubIssueUrl = gitHubIssueUrl
    }
}
