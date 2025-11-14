import SwiftUI

@MainActor
@Observable
final class DoneTodoListModel<S: Storage, G: GitHubIssueCreatorProtocol> {
    let repository: TodoRepository<S, G>
    let repositorySettings: GitHubRepositorySettings?
    let service: GitHubService?

    #if os(iOS)
        var editMode: EditMode = .inactive
    #endif
    var showDeleteAllAlert = false
    var showReopenAlert = false
    var pendingReopenItem: TodoItem?

    // Child models
    var addEditModel: AddEditTodoModel<S, G>?

    // In-memory set to track toggled item IDs (items whose done state has changed)
    private(set) var toggledItemIDs: Set<TodoItem.ID> = []

    // In-memory set to track deleted item IDs (items that should be hidden)
    private(set) var deletedItemIDs: Set<TodoItem.ID> = []

    // Computed property to get displayed done todos
    var displayedDoneTodos: [TodoItem] {
        // Explicitly reference both dependencies to ensure proper observation
        let allItems = repository.items
        let toggledIDs = toggledItemIDs
        let deletedIDs = deletedItemIDs

        return
            allItems
            .filter { item in
                // Include if: (done and not deleted) OR (active and toggled and not deleted)
                (item.isDone && !deletedIDs.contains(item.id))
                    || (!item.isDone && toggledIDs.contains(item.id)
                        && !deletedIDs.contains(item.id))
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // Check if an item's done state has been toggled in-memory
    func isToggledInMemory(_ item: TodoItem) -> Bool {
        toggledItemIDs.contains(item.id)
    }

    // Get the effective done state for display (considering in-memory toggles)
    func effectiveDoneState(for item: TodoItem) -> Bool {
        // Simply return the item's current isDone state from repository
        // The item displayed in the list already reflects the repository state
        return item.isDone
    }

    func loadDoneTodos() async {
        // Load items from storage first
        await repository.loadFromStorage()
        // Clear in-memory state
        toggledItemIDs.removeAll()
        deletedItemIDs.removeAll()
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

    func handleReopen(_ item: TodoItem) async {
        // Always show alert if item has a linked GitHub issue
        if item.gitHubIssueUrl != nil {
            pendingReopenItem = item
            showReopenAlert = true
        } else {
            // Toggle the in-memory state
            if toggledItemIDs.contains(item.id) {
                toggledItemIDs.remove(item.id)
            } else {
                toggledItemIDs.insert(item.id)
            }
            // Update repository
            await repository.toggleDone(item)
        }
    }

    func reopenWithoutIssueUpdate() async {
        guard let item = pendingReopenItem else { return }
        // Toggle the in-memory state
        if toggledItemIDs.contains(item.id) {
            toggledItemIDs.remove(item.id)
        } else {
            toggledItemIDs.insert(item.id)
        }
        // Update repository
        await repository.toggleDone(item)
        pendingReopenItem = nil
    }

    func reopenWithIssueUpdate() async {
        guard let item = pendingReopenItem else { return }
        // Toggle the in-memory state
        if toggledItemIDs.contains(item.id) {
            toggledItemIDs.remove(item.id)
        } else {
            toggledItemIDs.insert(item.id)
        }
        // Update repository
        await repository.toggleDone(item)
        pendingReopenItem = nil
    }

    func reopenGitHubIssue(item: TodoItem) async throws {
        guard let service = service,
            let issueNumber = item.gitHubIssueNumber
        else {
            return
        }

        _ = try await service.issueCreator.updateIssueState(
            owner: service.repositorySettings.owner,
            repo: service.repositorySettings.repo,
            issueNumber: issueNumber,
            state: "open",
            stateReason: nil
        )
        logger.debug("Reopened issue #\(issueNumber)")
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
                    ForEach(model.displayedDoneTodos) { item in
                        NavigationLink {
                            AddEditTodoView(model: model.createAddEditModel(editingItem: item))
                        } label: {
                            TodoRowView(
                                model: TodoRowModel(
                                    item: item,
                                    onToggle: {
                                        Task {
                                            await model.handleReopen(item)
                                        }
                                    },
                                    effectiveDoneState: model.effectiveDoneState(for: item)
                                )
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await model.handleDelete(item)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                let item = model.displayedDoneTodos[index]
                                await model.handleDelete(item)
                            }
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
                        model.showDeleteAllAlert = true
                    } label: {
                        Label("Delete All", systemImage: "trash")
                    }
                    .disabled(model.displayedDoneTodos.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .environment(\.editMode, $model.editMode)
        #endif
        .alert("Delete All Done Todos", isPresented: $model.showDeleteAllAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    await model.deleteAllDoneTodos()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete all done todos? This action cannot be undone.")
        }
        .alert("Reopen GitHub Issue?", isPresented: $model.showReopenAlert) {
            Button("Uncheck & Reopen") {
                if let item = model.pendingReopenItem {
                    Task {
                        await model.reopenWithIssueUpdate()
                        do {
                            try await model.reopenGitHubIssue(item: item)
                        } catch {
                            logger.error("Failed to reopen GitHub issue: \(error)")
                        }
                    }
                }
            }
            Button("Uncheck Only") {
                Task {
                    await model.reopenWithoutIssueUpdate()
                }
            }
            Button("Cancel", role: .cancel) {
                model.pendingReopenItem = nil
            }
        } message: {
            Text("This will reopen the linked GitHub issue.")
        }
    }
}
