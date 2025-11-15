import Foundation
import Logging
import Observation

@Observable
@MainActor
final class TodoRepository<S: Storage, G: GitHubIssueCreatorProtocol> {
    private let storage: S
    let issueCreator: G
    private var service: GitHubService?
    private(set) var items: [TodoItem] = []
    private(set) var lastCreatedIssue: GitHubIssue?
    private(set) var lastError: Error?

    init(storage: S, issueCreator: G, service: GitHubService? = nil) {
        self.storage = storage
        self.issueCreator = issueCreator
        self.service = service
    }

    /// Sets the GitHub service for fetching issue states.
    func setService(_ service: GitHubService?) {
        self.service = service
    }

    func loadFromStorage() async {
        await loadItems()
    }

    var activeTodos: [TodoItem] {
        items.filter { !$0.isDone }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var doneTodos: [TodoItem] {
        items.filter { $0.isDone }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Fetches items with their GitHub issue states.
    ///
    /// - Returns: Array of TodoItemWithIssueState containing items and their issue states.
    func fetchItemsWithIssueStates() async -> [TodoItemWithIssueState] {
        guard let service = service else {
            // No service available, return items without issue states
            return items.map { TodoItemWithIssueState(item: $0, issueState: nil) }
        }

        // Use withTaskGroup for parallel fetching of issue states
        return await withTaskGroup(of: (UUID, TodoItemWithIssueState).self) { group in
            // Add tasks for each item
            for item in items {
                group.addTask {
                    if let issueNumber = item.gitHubIssueNumber {
                        // Fetch the issue state from GitHub API
                        do {
                            let issue = try await service.issueCreator.getIssue(
                                owner: service.repositorySettings.owner,
                                repo: service.repositorySettings.repo,
                                issueNumber: issueNumber
                            )
                            let state = GitHubIssueState(rawValue: issue.state)
                            return (item.id, TodoItemWithIssueState(item: item, issueState: state))
                        } catch {
                            // Log error on main actor
                            await MainActor.run {
                                logger.error("Failed to fetch issue state for #\(issueNumber): \(error)")
                            }
                            // On error, return item without state
                            return (item.id, TodoItemWithIssueState(item: item, issueState: nil))
                        }
                    } else {
                        // No issue linked, return item without state
                        return (item.id, TodoItemWithIssueState(item: item, issueState: nil))
                    }
                }
            }

            // Collect results in a dictionary to maintain original order
            var resultsDict: [UUID: TodoItemWithIssueState] = [:]
            for await (id, itemWithState) in group {
                resultsDict[id] = itemWithState
            }

            // Return items in original order
            return items.compactMap { resultsDict[$0.id] }
        }
    }

    func add(
        title: String, detail: String = "", createIssue: Bool = true
    ) async throws {
        let item = TodoItem(title: title, detail: detail)

        // Trigger GitHub issue creation if enabled
        if createIssue {
            do {
                let issue = try await issueCreator.onTodoCreated(item)
                lastCreatedIssue = issue
                // Only save to storage after successful issue creation
                items.append(item)
                await saveItems()
                if let issue = issue {
                    await updateGitHubIssueUrl(for: item.id, url: issue.htmlUrl)
                }
            } catch {
                lastError = error
                logger.error("Failed to create GitHub issue", metadata: ["error": "\(error)"])
                throw error
            }
        } else {
            // No issue creation requested, save directly
            items.append(item)
            await saveItems()
        }
    }

    /// Adds a new todo item without creating a GitHub issue.
    ///
    /// - Parameters:
    ///   - title: The title of the todo.
    ///   - detail: Optional detail text.
    func addWithoutIssue(title: String, detail: String = "") async {
        let item = TodoItem(title: title, detail: detail)
        items.append(item)
        await saveItems()
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
                await updateGitHubIssueUrl(for: item.id, url: issue.htmlUrl)
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
    func updateGitHubIssueUrl(for id: UUID, url: String) async {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        items[index].gitHubIssueUrl = url
        await saveItems()
    }

    func update(_ item: TodoItem) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        var updatedItem = item
        updatedItem.updatedAt = Date()
        items[index] = updatedItem
        await saveItems()
    }

    func delete(_ item: TodoItem) async {
        items.removeAll { $0.id == item.id }
        await saveItems()
    }

    func delete(at offsets: IndexSet, from todos: [TodoItem]) async {
        let idsToDelete = offsets.map { todos[$0].id }
        items.removeAll { idsToDelete.contains($0.id) }
        await saveItems()
    }

    func toggleDone(_ item: TodoItem) async {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        items[index].isDone.toggle()
        items[index].updatedAt = Date()
        await saveItems()
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
