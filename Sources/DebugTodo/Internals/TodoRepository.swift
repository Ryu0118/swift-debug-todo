import Foundation
import Observation
import Logging

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
        loadItems()
    }

    var activeTodos: [TodoItem] {
        items.filter { !$0.isDone }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var doneTodos: [TodoItem] {
        items.filter { $0.isDone }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func add(title: String, detail: String = "", createIssue: Bool = true, onIssueCreationError: ((Error) -> Void)? = nil) {
        let item = TodoItem(title: title, detail: detail)
        items.append(item)
        saveItems()

        // Trigger GitHub issue creation if enabled
        if createIssue {
            Task {
                do {
                    let issue = try await issueCreator.onTodoCreated(item)
                    lastCreatedIssue = issue
                    if let issue = issue {
                        updateGitHubIssueUrl(for: item.id, url: issue.htmlUrl)
                    }
                } catch {
                    lastError = error
                    logger.error("Failed to create GitHub issue", metadata: ["error": "\(error)"])
                    await MainActor.run {
                        onIssueCreationError?(error)
                    }
                }
            }
        }
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
        saveItems()
    }

    func update(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        var updatedItem = item
        updatedItem.updatedAt = Date()
        items[index] = updatedItem
        saveItems()
    }

    func delete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }

    func delete(at offsets: IndexSet, from todos: [TodoItem]) {
        let idsToDelete = offsets.map { todos[$0].id }
        items.removeAll { idsToDelete.contains($0.id) }
        saveItems()
    }

    func toggleDone(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        items[index].isDone.toggle()
        items[index].updatedAt = Date()
        saveItems()
    }

    private func loadItems() {
        do {
            items = try storage.load()
        } catch {
            logger.error("Failed to load items", metadata: ["error": "\(error)"])
            items = []
        }
    }

    private func saveItems() {
        do {
            try storage.save(items)
        } catch {
            logger.error("Failed to save items", metadata: ["error": "\(error)"])
        }
    }
}
