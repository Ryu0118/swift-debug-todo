import Foundation

/// A protocol that defines storage operations for todo items.
public protocol Storage: Sendable {
    /// Saves todo items to storage.
    ///
    /// - Parameter items: The array of todo items to save.
    /// - Throws: An error if the save operation fails.
    func save(_ items: [TodoItem]) throws

    /// Loads todo items from storage.
    ///
    /// - Returns: An array of todo items.
    /// - Throws: An error if the load operation fails.
    func load() throws -> [TodoItem]

    /// Deletes all todo items from storage.
    ///
    /// - Throws: An error if the delete operation fails.
    func delete() throws
}
