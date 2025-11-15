import SwiftUI

@MainActor
@Observable
final class DoneTodoListModel<S: Storage, G: GitHubIssueCreatorProtocol>: TodoListManaging {
    struct DeleteAllContext: Equatable {}
    struct ToggleAlertContext: Equatable {
        let item: TodoItem
        let itemWithState: TodoItemWithIssueState
    }

    let repository: TodoRepository<S, G>
    let repositorySettings: GitHubRepositorySettings?

    // State management
    var todosDataState: DataState<[TodoItemWithIssueState], TodoError> = .idle
    var issueOperationState: IssueOperationState<TodoError> = .idle
    var deleteAllAlert: AlertState<DeleteAllContext> = .dismissed
    var toggleAlert: AlertState<ToggleAlertContext> = .dismissed

    // In-memory state management
    let stateManager = InMemoryStateManager()

    // GitHub issue operation service
    private(set) var issueOperationService: GitHubIssueOperationService?

    // Backward compatibility accessors
    var toggledItemIDs: Set<TodoItem.ID> { stateManager.toggledItemIDs }
    var deletedItemIDs: Set<TodoItem.ID> { stateManager.deletedItemIDs }

    // Protocol conformance
    var displayedTodos: [TodoItemWithIssueState] {
        displayedDoneTodos
    }

    // Computed property to get displayed done todos
    var displayedDoneTodos: [TodoItemWithIssueState] {
        let allItemsWithStates = todosDataState.value ?? []

        return
            allItemsWithStates
            .filter { itemWithState in
                let item = itemWithState.item
                // Include if: (done and not deleted) OR (active and toggled in this session and not deleted)
                return (item.isDone && !stateManager.isDeleted(item.id))
                    || (!item.isDone && stateManager.isToggled(item.id)
                        && !stateManager.isDeleted(item.id))
            }
            .sorted { $0.item.createdAt > $1.item.createdAt }
    }

    func loadDoneTodos() async {
        await loadTodos()
    }

    init(
        repository: TodoRepository<S, G>, repositorySettings: GitHubRepositorySettings? = nil,
        issueOperationService: GitHubIssueOperationService? = nil
    ) {
        self.repository = repository
        self.repositorySettings = repositorySettings
        self.issueOperationService = issueOperationService
    }

    func deleteAllDoneTodos() async {
        for todo in repository.doneTodos {
            await repository.delete(todo)
            stateManager.markAsDeleted(todo.id)
        }
    }

    func handleToggle(_ item: TodoItem) async {
        await handleToggleWithAlert(item) { [weak self] item, itemWithState in
            self?.toggleAlert = .presented(ToggleAlertContext(item: item, itemWithState: itemWithState))
        }
    }

    func toggleWithoutIssueUpdate(context: ToggleAlertContext) async {
        await toggleWithoutIssueUpdate(item: context.item)
        toggleAlert = .dismissed
    }

    func toggleWithIssueUpdate(context: ToggleAlertContext, stateReason: IssueStateReason?) async {
        await toggleWithIssueUpdate(
            item: context.item,
            stateReason: stateReason,
            issueOperationService: issueOperationService
        )
        toggleAlert = .dismissed
    }

    func handleDelete(_ item: TodoItem) async {
        // Update repository immediately, but hide from view
        await repository.delete(item)
        stateManager.markAsDeleted(item.id)
    }

    func createAddEditModel(editingItem: TodoItem) -> AddEditTodoModel<S, G> {
        AddEditTodoModel(
            repository: repository,
            repositorySettings: repositorySettings,
            service: issueOperationService?.service,
            editingItem: editingItem
        )
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
