import Logging
import SwiftUI

@MainActor
@Observable
final class TodoListModel<S: Storage, G: GitHubIssueCreatorProtocol> {
    struct ToggleAlertContext: Equatable {
        let item: TodoItem
        let itemWithState: TodoItemWithIssueState
    }

    struct DeleteAlertContext: Equatable {
        let item: TodoItem
    }

    var repository: TodoRepository<S, G>
    var service: GitHubService?
    var isShowingAddView = false

    // State management
    var todosDataState: DataState<[TodoItemWithIssueState], TodoError> = .idle
    var issueOperationState: IssueOperationState<TodoError> = .idle
    var toggleAlert: AlertState<ToggleAlertContext> = .dismissed
    var deleteAlert: AlertState<DeleteAlertContext> = .dismissed

    // Child models
    var addEditModel: AddEditTodoModel<S, G>?
    private(set) var doneListModel: DoneTodoListModel<S, G>

    // In-memory set to track toggled item IDs (to keep them visible in current session)
    private(set) var toggledItemIDs: Set<TodoItem.ID> = []

    // In-memory set to track deleted item IDs (items that should be hidden)
    private(set) var deletedItemIDs: Set<TodoItem.ID> = []

    // Computed property to get displayed active todos
    var displayedActiveTodos: [TodoItemWithIssueState] {
        guard let allItemsWithStates = todosDataState.value else { return [] }
        let toggledIDs = toggledItemIDs
        let deletedIDs = deletedItemIDs

        return
            allItemsWithStates
            .filter { itemWithState in
                let item = itemWithState.item
                // Include if: (active and not deleted) OR (done and toggled in this session and not deleted)
                return (!item.isDone && !deletedIDs.contains(item.id))
                    || (item.isDone && toggledIDs.contains(item.id)
                        && !deletedIDs.contains(item.id))
            }
            .sorted { $0.item.createdAt > $1.item.createdAt }
    }

    // Check if an item's done state has been toggled in-memory
    func isToggledInMemory(_ item: TodoItem) -> Bool {
        toggledItemIDs.contains(item.id)
    }

    func loadActiveTodos() async {
        todosDataState = .loading(todosDataState.value)

        // Load items from storage first
        await repository.loadFromStorage()
        // Fetch items with their issue states
        let items = await repository.fetchItemsWithIssueStates()

        todosDataState = .loaded(items)
    }

    func refresh() async {
        // Clear in-memory state
        await loadActiveTodos()
    }

    init(repository: TodoRepository<S, G>, service: GitHubService?) {
        self.repository = repository
        self.service = service
        // Set the service on repository for fetching issue states
        repository.setService(service)
        self.doneListModel = DoneTodoListModel(
            repository: repository,
            repositorySettings: service?.repositorySettings,
            service: service
        )
    }

    func handleToggle(_ item: TodoItem) async {
        // Find the corresponding TodoItemWithIssueState from todosDataState
        let itemWithState = todosDataState.value?.first { $0.item.id == item.id }

        // Show alert only if item has a linked GitHub issue AND the action would change the issue state
        if item.gitHubIssueUrl != nil, let itemWithState = itemWithState {
            // Determine if we need to show alert based on desired state change
            let wouldChangeIssueState: Bool
            if item.isDone {
                // Unchecking: only show alert if issue is currently closed (would need to reopen)
                wouldChangeIssueState = (itemWithState.issueState == .closed)
            } else {
                // Checking: only show alert if issue is currently open (would need to close)
                wouldChangeIssueState = (itemWithState.issueState == .open)
            }

            if wouldChangeIssueState {
                toggleAlert = .presented(ToggleAlertContext(item: item, itemWithState: itemWithState))
            } else {
                // Issue is already in desired state, perform toggle without showing alert
                if toggledItemIDs.contains(item.id) {
                    toggledItemIDs.remove(item.id)
                } else {
                    toggledItemIDs.insert(item.id)
                }
                await repository.toggleDone(item)
                let items = await repository.fetchItemsWithIssueStates()
                todosDataState = .loaded(items)
            }
        } else {
            // Toggle the in-memory state
            if toggledItemIDs.contains(item.id) {
                toggledItemIDs.remove(item.id)
            } else {
                toggledItemIDs.insert(item.id)
            }
            // Update repository
            await repository.toggleDone(item)

            // Refresh issue states after toggle
            let items = await repository.fetchItemsWithIssueStates()
            todosDataState = .loaded(items)
        }
    }

    func toggleWithIssueUpdate(context: ToggleAlertContext, stateReason: IssueStateReason?) async {
        let item = context.item

        issueOperationState = .inProgress

        // Mark item to keep visible in current session
        toggledItemIDs.insert(item.id)

        // Update repository
        await repository.toggleDone(item)

        // Update GitHub issue state by fetching current state from API
        do {
            try await updateIssueStateFromAPI(item: item, stateReason: stateReason)
            issueOperationState = .succeeded
        } catch {
            logger.error("Failed to update GitHub issue state: \(error)")
            let todoError = mapError(error)
            issueOperationState = .failed(todoError)
        }

        // Refresh issue states after toggle (toggledItemIDs keeps item visible)
        let items = await repository.fetchItemsWithIssueStates()
        todosDataState = .loaded(items)
        toggleAlert = .dismissed
    }

    private func updateIssueStateFromAPI(item: TodoItem, stateReason: IssueStateReason?) async throws {
        guard let service = service,
            let issueNumber = item.gitHubIssueNumber
        else {
            return
        }

        // Fetch current issue state from GitHub API
        let currentIssue = try await service.issueCreator.getIssue(
            owner: service.repositorySettings.owner,
            repo: service.repositorySettings.repo,
            issueNumber: issueNumber
        )

        // Determine new state based on current GitHub state
        let newState = currentIssue.state == "open" ? "closed" : "open"

        _ = try await service.issueCreator.updateIssueState(
            owner: service.repositorySettings.owner,
            repo: service.repositorySettings.repo,
            issueNumber: issueNumber,
            state: newState,
            stateReason: stateReason
        )
        logger.debug(
            "Updated issue #\(issueNumber) from \(currentIssue.state) to \(newState) with reason: \(stateReason?.rawValue ?? "nil")")
    }

    func toggleWithoutIssueUpdate(context: ToggleAlertContext) async {
        let item = context.item

        // Mark item to keep visible in current session
        toggledItemIDs.insert(item.id)

        // Update repository
        await repository.toggleDone(item)

        // Refresh issue states after toggle (toggledItemIDs keeps item visible)
        let items = await repository.fetchItemsWithIssueStates()
        todosDataState = .loaded(items)
        toggleAlert = .dismissed
    }

    func handleDelete(_ item: TodoItem) async {
        // Show alert only if item has a linked GitHub issue, is not done, AND the issue is open
        if item.gitHubIssueUrl != nil && !item.isDone {
            // Find the issue state
            let itemWithState = todosDataState.value?.first { $0.item.id == item.id }

            // Only show alert if issue is currently open (would need to close)
            if itemWithState?.issueState == .open {
                deleteAlert = .presented(DeleteAlertContext(item: item))
            } else {
                // Issue is already closed or state unknown, delete without alert
                await repository.delete(item)
                deletedItemIDs.insert(item.id)
            }
        } else {
            // Update repository immediately, but hide from view
            await repository.delete(item)
            deletedItemIDs.insert(item.id)
        }
    }

    func deleteWithoutClosingIssue(context: DeleteAlertContext) async {
        let item = context.item

        // Update repository immediately, but hide from view
        await repository.delete(item)
        deletedItemIDs.insert(item.id)
        deleteAlert = .dismissed
    }

    func deleteAndCloseIssue(context: DeleteAlertContext, stateReason: IssueStateReason) async {
        let item = context.item

        issueOperationState = .inProgress

        // Close GitHub issue first
        do {
            try await closeIssueForDelete(item: item, stateReason: stateReason)
            issueOperationState = .succeeded
        } catch {
            logger.error("Failed to close GitHub issue: \(error)")
            let todoError = mapError(error)
            issueOperationState = .failed(todoError)
        }

        // Update repository immediately, but hide from view
        await repository.delete(item)
        deletedItemIDs.insert(item.id)
        deleteAlert = .dismissed
    }

    private func closeIssueForDelete(item: TodoItem, stateReason: IssueStateReason) async throws {
        guard let service = service,
            let issueNumber = item.gitHubIssueNumber
        else {
            return
        }

        _ = try await service.issueCreator.updateIssueState(
            owner: service.repositorySettings.owner,
            repo: service.repositorySettings.repo,
            issueNumber: issueNumber,
            state: "closed",
            stateReason: stateReason
        )
        logger.debug("Closed issue #\(issueNumber) as \(stateReason.rawValue) before deleting todo")
    }

    func createAddEditModel(editingItem: TodoItem? = nil) -> AddEditTodoModel<S, G> {
        AddEditTodoModel(
            repository: repository,
            repositorySettings: service?.repositorySettings,
            service: service,
            editingItem: editingItem
        )
    }

    private func mapError(_ error: Error) -> TodoError {
        if let todoError = error as? TodoError {
            return todoError
        }
        return .unknown(error.localizedDescription)
    }

}

/// A view that displays the list of active todo items.
public struct TodoListView<S: Storage, G: GitHubIssueCreatorProtocol>: View {
    @Bindable var model: TodoListModel<S, G>

    /// Creates a new todo list view.
    ///
    /// - Parameters:
    ///   - storage: The storage to use for persisting todo items.
    ///   - issueCreator: The GitHub issue creator. Defaults to no-op.
    ///   - logLevel: The log level to use. If provided, bootstraps the logging system.
    public init(
        storage: S, issueCreator: G = NoOpGitHubIssueCreator(), logLevel: Logger.Level? = nil
    ) {
        bootstrapLogging(logLevel: logLevel)
        let repository = TodoRepository(storage: storage, issueCreator: issueCreator)
        self.model = TodoListModel(repository: repository, service: nil)
    }

    /// Creates a new todo list view with GitHub integration.
    ///
    /// - Parameters:
    ///   - storage: The storage to use for persisting todo items.
    ///   - service: The GitHub service for issue creation and settings.
    ///   - logLevel: The log level to use. If provided, bootstraps the logging system.
    public init(storage: S, service: GitHubService, logLevel: Logger.Level? = nil)
    where G == GitHubIssueCreator {
        bootstrapLogging(logLevel: logLevel)
        let repository = TodoRepository(storage: storage, issueCreator: service.issueCreator)
        self.model = TodoListModel(repository: repository, service: service)
    }

    private var toolbarContent: some ToolbarContent {
        TodoListToolbarContent(model: model)
    }


    private var contentView: some View {
        Group {
            if case .loading = model.todosDataState, model.todosDataState.value == nil {
                ProgressView()
            } else if model.displayedActiveTodos.isEmpty {
                ContentUnavailableView(
                    "No Active Todos",
                    systemImage: "checklist",
                    description: Text("Add a new todo to get started")
                )
            } else {
                List {
                    ForEach(model.displayedActiveTodos) { itemWithState in
                        let item = itemWithState.item
                        NavigationLink {
                            AddEditTodoView(model: model.createAddEditModel(editingItem: item))
                        } label: {
                            TodoRowView(
                                model: TodoRowModel(
                                    item: item,
                                    onToggle: {
                                        Task {
                                            await model.handleToggle(item)
                                        }
                                    },
                                    effectiveDoneState: item.isDone,
                                    issueState: itemWithState.issueState
                                )
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                Task {
                                    await model.handleDelete(item)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
            }
        }
    }

    public var body: some View {
        contentView
            .task {
                await model.loadActiveTodos()
            }
            .refreshable {
                await model.refresh()
            }
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $model.isShowingAddView, onDismiss: {
                Task {
                    await model.loadActiveTodos()
                }
            }) {
                AddEditTodoView(model: model.createAddEditModel())
            }
            .alert(
                model.toggleAlert.context?.itemWithState.issueState == .closed
                    ? "Reopen GitHub Issue?" : "Close GitHub Issue?",
                isPresented: Binding(
                    get: { model.toggleAlert.isPresented },
                    set: { if !$0 { model.toggleAlert = .dismissed } }
                )
            ) {
                if let context = model.toggleAlert.context {
                    ToggleAlertButtons(
                        issueState: context.itemWithState.issueState,
                        onToggleWithUpdate: { [context] stateReason in
                            await model.toggleWithIssueUpdate(context: context, stateReason: stateReason)
                        },
                        onToggleWithoutUpdate: { [context] in
                            await model.toggleWithoutIssueUpdate(context: context)
                        },
                        onCancel: {
                            model.toggleAlert = .dismissed
                        }
                    )
                }
            } message: {
                if let context = model.toggleAlert.context {
                    if context.itemWithState.issueState == .closed {
                        Text("This will reopen the linked GitHub issue.")
                    } else {
                        Text("This will close the linked GitHub issue. Choose a reason:")
                    }
                }
            }
            .alert("Delete Todo?", isPresented: Binding(
                get: { model.deleteAlert.isPresented },
                set: { if !$0 { model.deleteAlert = .dismissed } }
            )) {
                if let context = model.deleteAlert.context {
                    DeleteAlertButtons(
                        onDeleteAndClose: { [context] stateReason in
                            await model.deleteAndCloseIssue(context: context, stateReason: stateReason)
                        },
                        onDeleteOnly: { [context] in
                            await model.deleteWithoutClosingIssue(context: context)
                        },
                        onCancel: {
                            model.deleteAlert = .dismissed
                        }
                    )
                }
            } message: {
                Text("Do you want to close the linked GitHub issue? Choose a reason:")
            }
            .issueOperationOverlay(for: model.issueOperationState)
    }
}

@MainActor
private struct TodoListToolbarContent<S: Storage, G: GitHubIssueCreatorProtocol>: ToolbarContent {
    let model: TodoListModel<S, G>

    var body: some ToolbarContent {
        if let service = model.service {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    GitHubSettingsView(model: GitHubSettingsModel(service: service))
                } label: {
                    Image(systemName: "gearshape")
                }
            }

            if #available(iOS 26.0, macOS 26.0, *) {
                ToolbarSpacer(placement: .primaryAction)
            }
        }

        ToolbarItem(placement: .primaryAction) {
            NavigationLink {
                DoneTodoListView(model: model.doneListModel)
            } label: {
                Image(systemName: "checkmark.circle")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                model.isShowingAddView = true
            } label: {
                Image(systemName: "plus")
            }
        }
    }
}
