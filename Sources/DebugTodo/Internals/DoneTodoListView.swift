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
    var selectedTodoIDs: Set<TodoItem.ID> = []
    var showReopenAlert = false
    var pendingReopenItem: TodoItem?

    // Child models
    var addEditModel: AddEditTodoModel<S, G>?

    init(repository: TodoRepository<S, G>, repositorySettings: GitHubRepositorySettings? = nil, service: GitHubService? = nil) {
        self.repository = repository
        self.repositorySettings = repositorySettings
        self.service = service
    }

    func deleteAllDoneTodos() {
        let todosToDelete = repository.doneTodos
        for todo in todosToDelete {
            repository.delete(todo)
        }
    }

    func deleteSelectedTodos() {
        let todosToDelete = repository.doneTodos.filter { selectedTodoIDs.contains($0.id) }
        for todo in todosToDelete {
            repository.delete(todo)
        }
        selectedTodoIDs.removeAll()
    }

    func handleReopen(_ item: TodoItem) {
        // Always show alert if item has a linked GitHub issue
        if item.gitHubIssueUrl != nil {
            pendingReopenItem = item
            showReopenAlert = true
        } else {
            repository.toggleDone(item)
        }
    }

    func reopenWithoutIssueUpdate() {
        guard let item = pendingReopenItem else { return }
        repository.toggleDone(item)
        pendingReopenItem = nil
    }

    func reopenWithIssueUpdate() {
        guard let item = pendingReopenItem else { return }
        repository.toggleDone(item)
        pendingReopenItem = nil
    }

    func reopenGitHubIssue(item: TodoItem) async throws {
        guard let service = service,
              let issueNumber = item.gitHubIssueNumber else {
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
            if model.repository.doneTodos.isEmpty {
                ContentUnavailableView(
                    "No Completed Todos",
                    systemImage: "checkmark.circle",
                    description: Text("Completed todos will appear here")
                )
            } else {
                List(selection: $model.selectedTodoIDs) {
                    ForEach(model.repository.doneTodos) { item in
                        NavigationLink {
                            AddEditTodoView(model: model.createAddEditModel(editingItem: item))
                        } label: {
                            TodoRowView(
                                model: TodoRowModel(
                                    item: item,
                                    onToggle: {
                                        model.handleReopen(item)
                                    }
                                )
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                model.repository.delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        model.repository.delete(at: indexSet, from: model.repository.doneTodos)
                    }
                }
            }
        }
        .navigationTitle("Done")
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if model.editMode == .active && !model.selectedTodoIDs.isEmpty {
                    Button(role: .destructive) {
                        model.deleteSelectedTodos()
                    } label: {
                        Label("Delete Selected", systemImage: "trash")
                    }
                } else {
                    Button(role: .destructive) {
                        model.showDeleteAllAlert = true
                    } label: {
                        Label("Delete All", systemImage: "trash")
                    }
                    .disabled(model.repository.doneTodos.isEmpty)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .environment(\.editMode, $model.editMode)
        .onChange(of: model.editMode) { oldValue, newValue in
            if newValue == .inactive {
                model.selectedTodoIDs.removeAll()
            }
        }
        #endif
        .alert("Delete All Done Todos", isPresented: $model.showDeleteAllAlert) {
            Button("Delete", role: .destructive) {
                model.deleteAllDoneTodos()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete all done todos? This action cannot be undone.")
        }
        .alert("Reopen GitHub Issue?", isPresented: $model.showReopenAlert) {
            Button("Uncheck & Reopen") {
                if let item = model.pendingReopenItem {
                    model.reopenWithIssueUpdate()
                    Task {
                        do {
                            try await model.reopenGitHubIssue(item: item)
                        } catch {
                            logger.error("Failed to reopen GitHub issue: \(error)")
                        }
                    }
                }
            }
            Button("Uncheck Only") {
                model.reopenWithoutIssueUpdate()
            }
            Button("Cancel", role: .cancel) {
                model.pendingReopenItem = nil
            }
        } message: {
            Text("This will reopen the linked GitHub issue.")
        }
    }
}
