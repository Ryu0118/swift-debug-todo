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

    /// Creates a new todo item.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - title: The title of the todo item.
    ///   - detail: Additional details. Defaults to empty string.
    ///   - isDone: Completion status. Defaults to false.
    ///   - createdAt: Creation date. Defaults to current date.
    ///   - updatedAt: Last update date. Defaults to current date.
    public init(
        id: UUID = UUID(),
        title: String,
        detail: String = "",
        isDone: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isDone = isDone
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
