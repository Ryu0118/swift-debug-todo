import Foundation

/// A storage implementation that persists todo items to a file.
public final class FileStorage: Storage, Sendable {
    private let fileURL: URL

    /// Creates a new file storage instance.
    ///
    /// - Parameter fileURL: The URL of the file where todo items will be stored.
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Saves todo items to the file.
    ///
    /// - Parameter items: The array of todo items to save.
    /// - Throws: An error if encoding or writing to the file fails.
    public func save(_ items: [TodoItem]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: [.atomic])
    }

    /// Loads todo items from the file.
    ///
    /// - Returns: An array of todo items, or an empty array if the file doesn't exist.
    /// - Throws: An error if reading or decoding the file fails.
    public func load() throws -> [TodoItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode([TodoItem].self, from: data)
    }

    /// Deletes the file containing todo items.
    ///
    /// - Throws: An error if deleting the file fails.
    public func delete() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: fileURL)
    }
}
