import Logging

/// Protocol defining common behavior for todo list management
@MainActor
protocol TodoListManaging: AnyObject {
    associatedtype S: Storage
    associatedtype G: GitHubIssueCreatorProtocol

    var repository: TodoRepository<S, G> { get }
    var todosDataState: DataState<[TodoItemWithIssueState], TodoError> { get set }
    var issueOperationState: IssueOperationState<TodoError> { get set }
    var stateManager: InMemoryStateManager { get }

    /// Loads todos from storage and fetches their issue states
    func loadTodos() async

    /// Refreshes the todo list, clearing in-memory state
    func refresh() async

    /// Gets the displayed todos based on in-memory state
    var displayedTodos: [TodoItemWithIssueState] { get }
}

extension TodoListManaging {
    /// Default implementation for loading todos
    func loadTodos() async {
        todosDataState = .loading(todosDataState.value)

        // Load items from storage first
        await repository.loadFromStorage()
        // Fetch items with their issue states
        let items = await repository.fetchItemsWithIssueStates()

        todosDataState = .loaded(items)
    }

    /// Default implementation for refresh
    func refresh() async {
        // Clear in-memory state
        stateManager.clearAll()
        await loadTodos()
    }

    /// Checks if an item's done state has been toggled in-memory
    func isToggledInMemory(_ item: TodoItem) -> Bool {
        stateManager.isToggled(item.id)
    }

    /// Handles toggling a todo item's done state with alert presentation
    /// - Parameters:
    ///   - item: The item to toggle
    ///   - onShowAlert: Closure called when alert should be shown, passes item and itemWithState
    func handleToggleWithAlert(
        _ item: TodoItem,
        onShowAlert: (TodoItem, TodoItemWithIssueState) -> Void
    ) async {
        // Find the corresponding TodoItemWithIssueState from todosDataState
        let itemWithState = todosDataState.value?.first { $0.item.id == item.id }

        // Show alert only if item has a linked GitHub issue AND the action would change the issue state
        if item.gitHubIssueUrl != nil, let itemWithState = itemWithState {
            // Determine if we need to show alert based on desired state change
            let wouldChangeIssueState: Bool
            if itemWithState.issueState == nil {
                // Issue state is unknown (service not available), show alert to be safe
                wouldChangeIssueState = true
            } else if item.isDone {
                // Unchecking: only show alert if issue is currently closed (would need to reopen)
                wouldChangeIssueState = (itemWithState.issueState == .closed)
            } else {
                // Checking: only show alert if issue is currently open (would need to close)
                wouldChangeIssueState = (itemWithState.issueState == .open)
            }

            if wouldChangeIssueState {
                onShowAlert(item, itemWithState)
            } else {
                // Issue is already in desired state, perform toggle without showing alert
                stateManager.toggleToggledState(item.id)
                await repository.toggleDone(item)
                let items = await repository.fetchItemsWithIssueStates()
                todosDataState = .loaded(items)
            }
        } else {
            // Toggle the in-memory state
            stateManager.toggleToggledState(item.id)
            // Update repository
            await repository.toggleDone(item)

            // Refresh issue states after toggle
            let items = await repository.fetchItemsWithIssueStates()
            todosDataState = .loaded(items)
        }
    }

    /// Toggles item with GitHub issue update
    func toggleWithIssueUpdate(
        item: TodoItem,
        stateReason: IssueStateReason?,
        issueOperationService: GitHubIssueOperationService?
    ) async {
        issueOperationState = .inProgress

        // Mark item to keep visible in current session
        stateManager.markAsToggled(item.id)

        // Update repository
        await repository.toggleDone(item)

        // Update GitHub issue state
        if let issueOperationService = issueOperationService {
            do {
                try await issueOperationService.toggleIssueState(for: item, stateReason: stateReason)
                issueOperationState = .succeeded
            } catch {
                logger.error("Failed to update GitHub issue state: \(error)")
                let todoError = mapError(error)
                issueOperationState = .failed(todoError)
            }
        }

        // Refresh issue states after toggle (stateManager keeps item visible)
        let items = await repository.fetchItemsWithIssueStates()
        todosDataState = .loaded(items)
    }

    /// Toggles item without GitHub issue update
    func toggleWithoutIssueUpdate(item: TodoItem) async {
        // Mark item to keep visible in current session
        stateManager.markAsToggled(item.id)

        // Update repository
        await repository.toggleDone(item)

        // Refresh issue states after toggle (stateManager keeps item visible)
        let items = await repository.fetchItemsWithIssueStates()
        todosDataState = .loaded(items)
    }

    /// Maps an error to TodoError
    func mapError(_ error: Error) -> TodoError {
        if let todoError = error as? TodoError {
            return todoError
        }
        return .unknown(error.localizedDescription)
    }
}
