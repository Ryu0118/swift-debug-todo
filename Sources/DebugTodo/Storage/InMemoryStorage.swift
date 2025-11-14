import Foundation

/// A storage implementation that keeps todo items in memory.
public actor InMemoryStorage: Storage {
    private var items: [TodoItem] = []

    /// Creates a new in-memory storage instance.
    public init() {}

    /// Saves todo items to memory.
    ///
    /// - Parameter items: The array of todo items to save.
    public func save(_ items: [TodoItem]) async throws {
        self.items = items
    }

    /// Loads todo items from memory.
    ///
    /// - Returns: An array of todo items currently in memory.
    public func load() async throws -> [TodoItem] {
        items
    }

    /// Deletes all todo items from memory.
    public func delete() async throws {
        items.removeAll()
    }
}
