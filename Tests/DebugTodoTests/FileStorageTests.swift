import Foundation
import Testing

@testable import DebugTodo

@Suite("FileStorage Tests")
struct FileStorageTests {
    @Test("Save and load items")
    func saveAndLoad() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_saveAndLoad_\(UUID().uuidString).json")
        let storage = FileStorage(fileURL: fileURL)

        let items = [
            TodoItem(title: "Test 1", detail: "Detail 1"),
            TodoItem(title: "Test 2", detail: "Detail 2"),
        ]

        try await storage.save(items)
        let loadedItems = try await storage.load()

        #expect(loadedItems.count == 2)
        #expect(loadedItems[0].title == "Test 1")
        #expect(loadedItems[1].title == "Test 2")

        try await storage.delete()
    }

    @Test("Load empty storage")
    func loadEmptyStorage() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_loadEmpty_\(UUID().uuidString).json")
        let storage = FileStorage(fileURL: fileURL)

        let items = try await storage.load()
        #expect(items.isEmpty)

        try await storage.delete()
    }

    @Test("Delete all items")
    func delete() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_delete_\(UUID().uuidString).json")
        let storage = FileStorage(fileURL: fileURL)
        let items = [
            TodoItem(title: "Test 1", detail: "Detail 1")
        ]

        try await storage.save(items)
        try await storage.delete()
        let loadedItems = try await storage.load()

        #expect(loadedItems.isEmpty)
    }

    @Test("Persistence across instances")
    func persistenceAcrossInstances() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_persistence_\(UUID().uuidString).json")
        let storage = FileStorage(fileURL: fileURL)
        let items = [
            TodoItem(title: "Persistent", detail: "Should persist")
        ]

        try await storage.save(items)

        let newStorage = FileStorage(fileURL: fileURL)
        let loadedItems = try await newStorage.load()

        #expect(loadedItems.count == 1)
        #expect(loadedItems[0].title == "Persistent")

        try await newStorage.delete()
    }

    @Test("Overwrite existing data")
    func overwriteData() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_overwrite_\(UUID().uuidString).json")
        let storage = FileStorage(fileURL: fileURL)

        let firstItems = [
            TodoItem(title: "First", detail: "First detail")
        ]
        let secondItems = [
            TodoItem(title: "Second", detail: "Second detail")
        ]

        try await storage.save(firstItems)
        try await storage.save(secondItems)
        let loadedItems = try await storage.load()

        #expect(loadedItems.count == 1)
        #expect(loadedItems[0].title == "Second")

        try await storage.delete()
    }
}
