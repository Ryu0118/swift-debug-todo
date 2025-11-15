import SwiftUI

@MainActor
@Observable
final class DoneTodoListModel<S: Storage, G: GitHubIssueCreatorProtocol> {
    struct DeleteAllContext: Equatable {}
    struct ToggleAlertContext: Equatable {
        let item: TodoItem
        let itemWithState: TodoItemWithIssueState
    }

    let repository: TodoRepository<S, G>
    let repositorySettings: GitHubRepositorySettings?
    let service: GitHubService?

    // State management
    var todosDataState: DataState<[TodoItemWithIssueState], TodoError> = .idle
    var issueOperationState: IssueOperationState<TodoError> = .idle
    var deleteAllAlert: AlertState<DeleteAllContext> = .dismissed
    var toggleAlert: AlertState<ToggleAlertContext> = .dismissed

    // Child models
    var addEditModel: AddEditTodoModel<S, G>?

    // In-memory set to track toggled item IDs (to keep them visible in current session)
    private(set) var toggledItemIDs: Set<TodoItem.ID> = []

    // In-memory set to track deleted item IDs (items that should be hidden)
    private(set) var deletedItemIDs: Set<TodoItem.ID> = []

    // Computed property to get displayed done todos
    var displayedDoneTodos: [TodoItemWithIssueState] {
        // Explicitly reference both dependencies to ensure proper observation
        let allItemsWithStates = todosDataState.value ?? []
        let toggledIDs = toggledItemIDs
        let deletedIDs = deletedItemIDs

        return
            allItemsWithStates
            .filter { itemWithState in
                let item = itemWithState.item
                // Include if: (done and not deleted) OR (active and toggled in this session and not deleted)
                return (item.isDone && !deletedIDs.contains(item.id))
                    || (!item.isDone && toggledIDs.contains(item.id)
                        && !deletedIDs.contains(item.id))
            }
            .sorted { $0.item.createdAt > $1.item.createdAt }
    }

    // Check if an item's done state has been toggled in-memory
    func isToggledInMemory(_ item: TodoItem) -> Bool {
        toggledItemIDs.contains(item.id)
    }

    func loadDoneTodos() async {
        todosDataState = .loading(todosDataState.value)

        // Load items from storage first
        await repository.loadFromStorage()
        // Fetch items with their issue states
        let items = await repository.fetchItemsWithIssueStates()

        todosDataState = .loaded(items)
    }

    func refresh() async {
        // Clear in-memory state
        await loadDoneTodos()
    }

    init(
        repository: TodoRepository<S, G>, repositorySettings: GitHubRepositorySettings? = nil,
        service: GitHubService? = nil
    ) {
        self.repository = repository
        self.repositorySettings = repositorySettings
        self.service = service
    }

    func deleteAllDoneTodos() async {
        for todo in repository.doneTodos {
            await repository.delete(todo)
            deletedItemIDs.insert(todo.id)
        }
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

    func handleDelete(_ item: TodoItem) async {
        // Update repository immediately, but hide from view
        await repository.delete(item)
        deletedItemIDs.insert(item.id)
    }

    func createAddEditModel(editingItem: TodoItem) -> AddEditTodoModel<S, G> {
        AddEditTodoModel(
            repository: repository,
            repositorySettings: repositorySettings,
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

struct DoneTodoListView<S: Storage, G: GitHubIssueCreatorProtocol>: View {
    @Bindable var model: DoneTodoListModel<S, G>

    var body: some View {
        Group {
            if model.displayedDoneTodos.isEmpty {
                ContentUnavailableView(
                    "No Completed Todos",
                    systemImage: "checkmark.circle",
                    description: Text("Completed todos will appear here")
                )
            } else {
                List {
                    ForEach(model.displayedDoneTodos) { itemWithState in
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
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                }
            }
        }
        .task {
            await model.loadDoneTodos()
        }
        .refreshable {
            await model.refresh()
        }
        .navigationTitle("Done")
        #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        model.deleteAllAlert = .presented(DoneTodoListModel<S, G>.DeleteAllContext())
                    } label: {
                        Label("Delete All", systemImage: "trash")
                    }
                    .disabled(model.displayedDoneTodos.isEmpty)
                }
            }
        #endif
        .alert("Delete All Done Todos", isPresented: Binding(
            get: { model.deleteAllAlert.isPresented },
            set: { if !$0 { model.deleteAllAlert = .dismissed } }
        )) {
            Button("Delete", role: .destructive) {
                Task {
                    await model.deleteAllDoneTodos()
                }
            }
            Button("Cancel", role: .cancel) {
                model.deleteAllAlert = .dismissed
            }
        } message: {
            Text("Are you sure you want to delete all done todos? This action cannot be undone.")
        }
        .alert(
            model.toggleAlert.context?.itemWithState.issueState == .open
                ? "Close GitHub Issue?" : "Reopen GitHub Issue?",
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
                if context.itemWithState.issueState == .open {
                    Text("This will close the linked GitHub issue. Choose a reason:")
                } else {
                    Text("This will reopen the linked GitHub issue.")
                }
            }
        }
        .issueOperationOverlay(for: model.issueOperationState)
    }
}
