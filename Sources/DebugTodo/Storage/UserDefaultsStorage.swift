import Foundation

/// A storage implementation that persists todo items using UserDefaults.
public final class UserDefaultsStorage: Storage, Sendable {
    private nonisolated(unsafe) let userDefaults: UserDefaults
    private let key: String

    /// Creates a new UserDefaults storage instance.
    ///
    /// - Parameters:
    ///   - userDefaults: The UserDefaults instance to use. Defaults to `.standard`.
    ///   - key: The key used to store todo items. Defaults to "debugTodoItems".
    public init(userDefaults: UserDefaults = .standard, key: String = "debugTodoItems") {
        self.userDefaults = userDefaults
        self.key = key
    }

    /// Saves todo items to UserDefaults.
    ///
    /// - Parameter items: The array of todo items to save.
    /// - Throws: An error if encoding fails.
    public func save(_ items: [TodoItem]) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(items)
        userDefaults.set(data, forKey: key)
    }

    /// Loads todo items from UserDefaults.
    ///
    /// - Returns: An array of todo items, or an empty array if no data is stored.
    /// - Throws: An error if decoding fails.
    public func load() throws -> [TodoItem] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }
        let decoder = JSONDecoder()
        return try decoder.decode([TodoItem].self, from: data)
    }

    /// Deletes all todo items from UserDefaults.
    public func delete() throws {
        userDefaults.removeObject(forKey: key)
    }
}
