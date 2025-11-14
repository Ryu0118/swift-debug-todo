import Foundation
import Testing

@testable import DebugTodo

@Suite("TodoRepository Tests")
@MainActor
struct TodoRepositoryTests {
    @Test("Add new todo item")
    func addTodo() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: NoOpGitHubIssueCreator())

        repository.addWithoutIssue(title: "Test Todo", detail: "Test Detail")

        #expect(repository.items.count == 1)
        #expect(repository.items[0].title == "Test Todo")
        #expect(repository.items[0].detail == "Test Detail")
        #expect(repository.items[0].isDone == false)
    }

    @Test("Update existing todo item")
    func updateTodo() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: NoOpGitHubIssueCreator())

        repository.addWithoutIssue(title: "Original", detail: "Original detail")
        var item = repository.items[0]
        item.title = "Updated"
        item.detail = "Updated detail"

        repository.update(item)

        #expect(repository.items[0].title == "Updated")
        #expect(repository.items[0].detail == "Updated detail")
    }

    @Test("Delete todo item")
    func deleteTodo() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: NoOpGitHubIssueCreator())

        repository.addWithoutIssue(title: "To Delete", detail: "")
        let item = repository.items[0]

        repository.delete(item)

        #expect(repository.items.isEmpty)
    }

    @Test("Toggle todo done status")
    func toggleDone() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: NoOpGitHubIssueCreator())

        repository.addWithoutIssue(title: "Toggle Test", detail: "")
        let item = repository.items[0]

        repository.toggleDone(item)
        #expect(repository.items[0].isDone == true)

        repository.toggleDone(repository.items[0])
        #expect(repository.items[0].isDone == false)
    }

    @Test("Active todos filter")
    func activeTodos() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: NoOpGitHubIssueCreator())

        repository.addWithoutIssue(title: "Active 1", detail: "")
        repository.addWithoutIssue(title: "Active 2", detail: "")
        repository.addWithoutIssue(title: "Done 1", detail: "")

        repository.toggleDone(repository.items[2])

        #expect(repository.activeTodos.count == 2)
        #expect(repository.activeTodos.allSatisfy { !$0.isDone })
    }

    @Test("Done todos filter")
    func doneTodos() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: NoOpGitHubIssueCreator())

        repository.addWithoutIssue(title: "Active 1", detail: "")
        repository.addWithoutIssue(title: "Done 1", detail: "")
        repository.addWithoutIssue(title: "Done 2", detail: "")

        repository.toggleDone(repository.items[1])
        repository.toggleDone(repository.items[2])

        #expect(repository.doneTodos.count == 2)
        #expect(repository.doneTodos.allSatisfy { $0.isDone })
    }

    @Test("Persistence with storage")
    func persistence() throws {
        let storage = InMemoryStorage()
        let repository1 = TodoRepository(storage: storage, issueCreator: NoOpGitHubIssueCreator())

        repository1.addWithoutIssue(title: "Persistent", detail: "Should persist")

        let repository2 = TodoRepository(storage: storage, issueCreator: NoOpGitHubIssueCreator())
        #expect(repository2.items.count == 1)
        #expect(repository2.items[0].title == "Persistent")
    }

    @Test("Delete at offsets")
    func deleteAtOffsets() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: NoOpGitHubIssueCreator())

        repository.addWithoutIssue(title: "Item 1", detail: "")
        repository.addWithoutIssue(title: "Item 2", detail: "")
        repository.addWithoutIssue(title: "Item 3", detail: "")

        let activeTodos = repository.activeTodos
        repository.delete(at: IndexSet(integer: 1), from: activeTodos)

        #expect(repository.items.count == 2)
    }
}
