import Logging
import SwiftUI

@MainActor
@Observable
final class TodoListModel<S: Storage, G: GitHubIssueCreatorProtocol>: TodoListManaging {
    struct ToggleAlertContext: Equatable {
        let item: TodoItem
        let itemWithState: TodoItemWithIssueState
    }

    struct DeleteAlertContext: Equatable {
        let item: TodoItem
    }

    var repository: TodoRepository<S, G>
    var isShowingAddView = false

    // State management
    var todosDataState: DataState<[TodoItemWithIssueState], TodoError> = .idle
    var issueOperationState: IssueOperationState<TodoError> = .idle
    var toggleAlert: AlertState<ToggleAlertContext> = .dismissed
    var deleteAlert: AlertState<DeleteAlertContext> = .dismissed

    // Child models
    private(set) var doneListModel: DoneTodoListModel<S, G>

    // In-memory state management
    let stateManager = InMemoryStateManager()

    // GitHub issue operation service
    private(set) var issueOperationService: GitHubIssueOperationService?

    // Backward compatibility accessors
    var toggledItemIDs: Set<TodoItem.ID> { stateManager.toggledItemIDs }
    var deletedItemIDs: Set<TodoItem.ID> { stateManager.deletedItemIDs }

    // Protocol conformance
    var displayedTodos: [TodoItemWithIssueState] {
        displayedActiveTodos
    }

    // Computed property to get displayed active todos
    var displayedActiveTodos: [TodoItemWithIssueState] {
        guard let allItemsWithStates = todosDataState.value else { return [] }

        return
            allItemsWithStates
            .filter { itemWithState in
                let item = itemWithState.item
                // Include if: (active and not deleted) OR (done and toggled in this session and not deleted)
                return (!item.isDone && !stateManager.isDeleted(item.id))
                    || (item.isDone && stateManager.isToggled(item.id)
                        && !stateManager.isDeleted(item.id))
            }
            .sorted { $0.item.createdAt > $1.item.createdAt }
    }

    func loadActiveTodos() async {
        await loadTodos()
    }

    init(repository: TodoRepository<S, G>, service: GitHubService?) {
        self.repository = repository
        // Set the service on repository for fetching issue states
        repository.setService(service)
        let issueOpService = service.map { GitHubIssueOperationService(service: $0) }
        self.issueOperationService = issueOpService
        self.doneListModel = DoneTodoListModel(
            repository: repository,
            repositorySettings: service?.repositorySettings,
            issueOperationService: issueOpService
        )
    }

    func handleToggle(_ item: TodoItem) async {
        await handleToggleWithAlert(item) { [weak self] item, itemWithState in
            self?.toggleAlert = .presented(
                ToggleAlertContext(item: item, itemWithState: itemWithState))
        }
    }

    func toggleWithIssueUpdate(context: ToggleAlertContext, stateReason: IssueStateReason?) async {
        await toggleWithIssueUpdate(
            item: context.item,
            stateReason: stateReason,
            issueOperationService: issueOperationService
        )
        toggleAlert = .dismissed
    }

    func toggleWithoutIssueUpdate(context: ToggleAlertContext) async {
        await toggleWithoutIssueUpdate(item: context.item)
        toggleAlert = .dismissed
    }

    func handleDelete(_ item: TodoItem) async {
        // Show alert only if item has a linked GitHub issue, is not done, AND the issue is open/unknown
        if item.gitHubIssueUrl != nil && !item.isDone {
            // Find the issue state
            let itemWithState = todosDataState.value?.first { $0.item.id == item.id }

            // Only show alert if issue is currently open or unknown (would need to close)
            let shouldShowAlert =
                itemWithState?.issueState == .open || itemWithState?.issueState == nil
            if shouldShowAlert {
                deleteAlert = .presented(DeleteAlertContext(item: item))
            } else {
                // Issue is already closed, delete without alert
                await repository.delete(item)
                stateManager.markAsDeleted(item.id)
            }
        } else {
            // Update repository immediately, but hide from view
            await repository.delete(item)
            stateManager.markAsDeleted(item.id)
        }
    }

    func deleteWithoutClosingIssue(context: DeleteAlertContext) async {
        let item = context.item

        // Update repository immediately, but hide from view
        await repository.delete(item)
        stateManager.markAsDeleted(item.id)
        deleteAlert = .dismissed
    }

    func deleteAndCloseIssue(context: DeleteAlertContext, stateReason: IssueStateReason) async {
        let item = context.item

        issueOperationState = .inProgress

        // Close GitHub issue first
        if let issueOperationService = issueOperationService {
            do {
                try await issueOperationService.closeIssue(for: item, stateReason: stateReason)
                issueOperationState = .succeeded
            } catch {
                logger.error("Failed to close GitHub issue: \(error)")
                let todoError = mapError(error)
                issueOperationState = .failed(todoError)
            }
        }

        // Update repository immediately, but hide from view
        await repository.delete(item)
        stateManager.markAsDeleted(item.id)
        deleteAlert = .dismissed
    }

    func createAddEditModel(editingItem: TodoItem? = nil) -> AddEditTodoModel<S, G> {
        AddEditTodoModel(
            repository: repository,
            repositorySettings: issueOperationService?.service.repositorySettings,
            service: issueOperationService?.service,
            editingItem: editingItem
        )
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
            .sheet(
                isPresented: $model.isShowingAddView,
                onDismiss: {
                    Task {
                        await model.loadActiveTodos()
                    }
                }
            ) {
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
                            await model.toggleWithIssueUpdate(
                                context: context, stateReason: stateReason)
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
            .alert(
                "Delete Todo?",
                isPresented: Binding(
                    get: { model.deleteAlert.isPresented },
                    set: { if !$0 { model.deleteAlert = .dismissed } }
                )
            ) {
                if let context = model.deleteAlert.context {
                    DeleteAlertButtons(
                        onDeleteAndClose: { [context] stateReason in
                            await model.deleteAndCloseIssue(
                                context: context, stateReason: stateReason)
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
        if let service = model.issueOperationService?.service {
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
