import Foundation

/// A wrapper that combines a TodoItem with its GitHub issue state.
public struct TodoItemWithIssueState: Identifiable, Sendable, Equatable {
    /// The underlying todo item.
    public let item: TodoItem

    /// The state of the linked GitHub issue, if any.
    public let issueState: GitHubIssueState?

    /// Unique identifier forwarded from the todo item.
    public var id: UUID { item.id }

    public init(item: TodoItem, issueState: GitHubIssueState? = nil) {
        self.item = item
        self.issueState = issueState
    }
}
