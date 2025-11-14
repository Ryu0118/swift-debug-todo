import Foundation
import os

/// A storage implementation that keeps todo items in memory.
public final class InMemoryStorage: Storage, Sendable {
    private let items = OSAllocatedUnfairLock<[TodoItem]>(initialState: [])

    /// Creates a new in-memory storage instance.
    public init() {}

    /// Saves todo items to memory.
    ///
    /// - Parameter items: The array of todo items to save.
    public func save(_ items: [TodoItem]) async throws {
        self.items.withLock { $0 = items }
    }

    /// Loads todo items from memory.
    ///
    /// - Returns: An array of todo items currently in memory.
    public func load() async throws -> [TodoItem] {
        items.withLock { $0 }
    }

    /// Deletes all todo items from memory.
    public func delete() async throws {
        items.withLock { $0.removeAll() }
    }
}
