import Testing

@testable import DebugTodo

@Suite("InMemoryStorage Tests")
struct InMemoryStorageTests {
    @Test("Save and load items")
    func saveAndLoad() throws {
        let storage = InMemoryStorage()
        let items = [
            TodoItem(title: "Test 1", detail: "Detail 1"),
            TodoItem(title: "Test 2", detail: "Detail 2"),
        ]

        try storage.save(items)
        let loadedItems = try storage.load()

        #expect(loadedItems.count == 2)
        #expect(loadedItems[0].title == "Test 1")
        #expect(loadedItems[1].title == "Test 2")
    }

    @Test("Load empty storage")
    func loadEmptyStorage() throws {
        let storage = InMemoryStorage()
        let items = try storage.load()
        #expect(items.isEmpty)
    }

    @Test("Delete all items")
    func delete() throws {
        let storage = InMemoryStorage()
        let items = [
            TodoItem(title: "Test 1", detail: "Detail 1")
        ]

        try storage.save(items)
        try storage.delete()
        let loadedItems = try storage.load()

        #expect(loadedItems.isEmpty)
    }

    @Test("Overwrite existing data")
    func overwriteData() throws {
        let storage = InMemoryStorage()
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
