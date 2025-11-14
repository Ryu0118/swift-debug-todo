import Foundation
import Logging
import Observation

@Observable
@MainActor
final class TodoRepository<S: Storage, G: GitHubIssueCreatorProtocol> {
    private let storage: S
    let issueCreator: G
    private(set) var items: [TodoItem] = []
    private(set) var lastCreatedIssue: GitHubIssue?
    private(set) var lastError: Error?

    init(storage: S, issueCreator: G) {
        self.storage = storage
        self.issueCreator = issueCreator
        Task { await loadItems() }
    }

    var activeTodos: [TodoItem] {
        items.filter { !$0.isDone }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var doneTodos: [TodoItem] {
        items.filter { $0.isDone }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func add(
        title: String, detail: String = "", createIssue: Bool = true
    ) async throws {
        let item = TodoItem(title: title, detail: detail)
        items.append(item)
        await saveItems()

        // Trigger GitHub issue creation if enabled
        if createIssue {
            do {
                let issue = try await issueCreator.onTodoCreated(item)
                lastCreatedIssue = issue
                if let issue = issue {
                    updateGitHubIssueUrl(for: item.id, url: issue.htmlUrl)
                }
            } catch {
                lastError = error
                logger.error("Failed to create GitHub issue", metadata: ["error": "\(error)"])
                throw error
            }
        }
    }

    /// Adds a new todo item without creating a GitHub issue.
    ///
    /// - Parameters:
    ///   - title: The title of the todo.
    ///   - detail: Optional detail text.
    func addWithoutIssue(title: String, detail: String = "") {
        let item = TodoItem(title: title, detail: detail)
        items.append(item)
        Task { await saveItems() }
    }

    /// Manually creates a GitHub issue for the given todo item.
    ///
    /// - Parameter item: The todo item to create an issue for.
    /// - Returns: The created GitHub issue, or nil if issue creation is disabled.
    func createGitHubIssue(for item: TodoItem) async throws -> GitHubIssue? {
        lastError = nil
        do {
            let issue = try await issueCreator.createIssue(for: item)
            lastCreatedIssue = issue
            if let issue = issue {
                updateGitHubIssueUrl(for: item.id, url: issue.htmlUrl)
            }
            return issue
        } catch {
            lastError = error
            throw error
        }
    }

    /// Updates the GitHub issue URL for a todo item.
    ///
    /// - Parameters:
    ///   - id: The ID of the todo item.
    ///   - url: The URL of the GitHub issue.
    func updateGitHubIssueUrl(for id: UUID, url: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        items[index].gitHubIssueUrl = url
        Task { await saveItems() }
    }

    func update(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        var updatedItem = item
        updatedItem.updatedAt = Date()
        items[index] = updatedItem
        Task { await saveItems() }
    }

    func delete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        Task { await saveItems() }
    }

    func delete(at offsets: IndexSet, from todos: [TodoItem]) {
        let idsToDelete = offsets.map { todos[$0].id }
        items.removeAll { idsToDelete.contains($0.id) }
        Task { await saveItems() }
    }

    func toggleDone(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        items[index].isDone.toggle()
        items[index].updatedAt = Date()
        Task { await saveItems() }
    }

    private func loadItems() async {
        do {
            items = try await storage.load()
        } catch {
            logger.error("Failed to load items", metadata: ["error": "\(error)"])
            items = []
        }
    }

    private func saveItems() async {
        do {
            try await storage.save(items)
        } catch {
            logger.error("Failed to save items", metadata: ["error": "\(error)"])
        }
    }
}
