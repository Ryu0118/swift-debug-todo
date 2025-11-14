import Foundation
import Testing

@testable import DebugTodo

@Suite("TodoRepository Tests")
@MainActor
struct TodoRepositoryTests {
    @Test("Add new todo item")
    func addTodo() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: NoOpGitHubIssueCreator())

        await repository.addWithoutIssue(title: "Test Todo", detail: "Test Detail")

        #expect(repository.items.count == 1)
        #expect(repository.items[0].title == "Test Todo")
        #expect(repository.items[0].detail == "Test Detail")
        #expect(repository.items[0].isDone == false)
    }

    @Test("Update existing todo item")
    func updateTodo() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: NoOpGitHubIssueCreator())

        await repository.addWithoutIssue(title: "Original", detail: "Original detail")
        var item = repository.items[0]
        item.title = "Updated"
        item.detail = "Updated detail"

        await repository.update(item)

        #expect(repository.items[0].title == "Updated")
        #expect(repository.items[0].detail == "Updated detail")
    }

    @Test("Delete todo item")
    func deleteTodo() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: NoOpGitHubIssueCreator())

        await repository.addWithoutIssue(title: "To Delete", detail: "")
        let item = repository.items[0]

        await repository.delete(item)

        #expect(repository.items.isEmpty)
    }

    @Test("Toggle todo done status")
    func toggleDone() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: NoOpGitHubIssueCreator())

        await repository.addWithoutIssue(title: "Toggle Test", detail: "")
        let item = repository.items[0]

        await repository.toggleDone(item)
        #expect(repository.items[0].isDone == true)

        await repository.toggleDone(repository.items[0])
        #expect(repository.items[0].isDone == false)
    }

    @Test("Active todos filter")
    func activeTodos() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: NoOpGitHubIssueCreator())

        await repository.addWithoutIssue(title: "Active 1", detail: "")
        await repository.addWithoutIssue(title: "Active 2", detail: "")
        await repository.addWithoutIssue(title: "Done 1", detail: "")

        await repository.toggleDone(repository.items[2])

        #expect(repository.activeTodos.count == 2)
        #expect(repository.activeTodos.allSatisfy { !$0.isDone })
    }

    @Test("Done todos filter")
    func doneTodos() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: NoOpGitHubIssueCreator())

        await repository.addWithoutIssue(title: "Active 1", detail: "")
        await repository.addWithoutIssue(title: "Done 1", detail: "")
        await repository.addWithoutIssue(title: "Done 2", detail: "")

        await repository.toggleDone(repository.items[1])
        await repository.toggleDone(repository.items[2])

        #expect(repository.doneTodos.count == 2)
        #expect(repository.doneTodos.allSatisfy { $0.isDone })
    }

    @Test("Persistence with storage")
    func persistence() async throws {
        let storage = InMemoryStorage()
        let repository1 = TodoRepository(storage: storage, issueCreator: NoOpGitHubIssueCreator())

        await repository1.addWithoutIssue(title: "Persistent", detail: "Should persist")

        // Wait for the save to complete
        try await Task.sleep(for: .milliseconds(100))

        let repository2 = TodoRepository(storage: storage, issueCreator: NoOpGitHubIssueCreator())
        // Explicitly load from storage
        await repository2.loadFromStorage()

        #expect(repository2.items.count == 1)
        #expect(repository2.items[0].title == "Persistent")
    }

    @Test("Delete at offsets")
    func deleteAtOffsets() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: NoOpGitHubIssueCreator())

        await repository.addWithoutIssue(title: "Item 1", detail: "")
        await repository.addWithoutIssue(title: "Item 2", detail: "")
        await repository.addWithoutIssue(title: "Item 3", detail: "")

        let activeTodos = repository.activeTodos
        await repository.delete(at: IndexSet(integer: 1), from: activeTodos)

        #expect(repository.items.count == 2)
    }
}
