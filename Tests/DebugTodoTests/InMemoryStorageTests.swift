import Testing

@testable import DebugTodo

@Suite("InMemoryStorage Tests")
struct InMemoryStorageTests {
    @Test("Save and load items")
    func saveAndLoad() async throws {
        let storage = InMemoryStorage()
        let items = [
            TodoItem(title: "Test 1", detail: "Detail 1"),
            TodoItem(title: "Test 2", detail: "Detail 2"),
        ]

        try await storage.save(items)
        let loadedItems = try await storage.load()

        #expect(loadedItems.count == 2)
        #expect(loadedItems[0].title == "Test 1")
        #expect(loadedItems[1].title == "Test 2")
    }

    @Test("Load empty storage")
    func loadEmptyStorage() async throws {
        let storage = InMemoryStorage()
        let items = try await storage.load()
        #expect(items.isEmpty)
    }

    @Test("Delete all items")
    func delete() async throws {
        let storage = InMemoryStorage()
        let items = [
            TodoItem(title: "Test 1", detail: "Detail 1")
        ]

        try await storage.save(items)
        try await storage.delete()
        let loadedItems = try await storage.load()

        #expect(loadedItems.isEmpty)
    }

    @Test("Overwrite existing data")
    func overwriteData() async throws {
        let storage = InMemoryStorage()
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
    }
}
