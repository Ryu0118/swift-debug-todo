import Testing
import Foundation
@testable import DebugTodo

@Suite("FileStorage Tests")
struct FileStorageTests {
    @Test("Save and load items")
    func saveAndLoad() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_saveAndLoad_\(UUID().uuidString).json")
        let storage = FileStorage(fileURL: fileURL)
        defer { try? storage.delete() }

        let items = [
            TodoItem(title: "Test 1", detail: "Detail 1"),
            TodoItem(title: "Test 2", detail: "Detail 2")
        ]

        try storage.save(items)
        let loadedItems = try storage.load()

        #expect(loadedItems.count == 2)
        #expect(loadedItems[0].title == "Test 1")
        #expect(loadedItems[1].title == "Test 2")
    }

    @Test("Load empty storage")
    func loadEmptyStorage() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_loadEmpty_\(UUID().uuidString).json")
        let storage = FileStorage(fileURL: fileURL)
        defer { try? storage.delete() }

        let items = try storage.load()
        #expect(items.isEmpty)
    }

    @Test("Delete all items")
    func delete() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_delete_\(UUID().uuidString).json")
        let storage = FileStorage(fileURL: fileURL)
        let items = [
            TodoItem(title: "Test 1", detail: "Detail 1")
        ]

        try storage.save(items)
        try storage.delete()
        let loadedItems = try storage.load()

        #expect(loadedItems.isEmpty)
    }

    @Test("Persistence across instances")
    func persistenceAcrossInstances() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_persistence_\(UUID().uuidString).json")
        let storage = FileStorage(fileURL: fileURL)
        let items = [
            TodoItem(title: "Persistent", detail: "Should persist")
        ]

        try storage.save(items)

        let newStorage = FileStorage(fileURL: fileURL)
        let loadedItems = try newStorage.load()

        #expect(loadedItems.count == 1)
        #expect(loadedItems[0].title == "Persistent")

        try newStorage.delete()
    }

    @Test("Overwrite existing data")
    func overwriteData() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_overwrite_\(UUID().uuidString).json")
        let storage = FileStorage(fileURL: fileURL)
        defer { try? storage.delete() }

        let firstItems = [
            TodoItem(title: "First", detail: "First detail")
        ]
        let secondItems = [
            TodoItem(title: "Second", detail: "Second detail")
        ]

        try storage.save(firstItems)
        try storage.save(secondItems)
        let loadedItems = try storage.load()

        #expect(loadedItems.count == 1)
        #expect(loadedItems[0].title == "Second")
    }
}
