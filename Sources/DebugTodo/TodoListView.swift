import Logging
import SwiftUI

@MainActor
@Observable
final class TodoListModel<S: Storage, G: GitHubIssueCreatorProtocol> {
    var repository: TodoRepository<S, G>
    var service: GitHubService?
    var isShowingAddView = false
    var showStateChangeAlert = false
    var pendingToggleItem: TodoItem?
    var showDeleteAlert = false
    var pendingDeleteItem: TodoItem?
    #if os(iOS)
        var editMode: EditMode = .inactive
    #endif

    // Child models
    var addEditModel: AddEditTodoModel<S, G>?

    // In-memory set to track toggled item IDs (items whose done state has changed)
    private(set) var toggledItemIDs: Set<TodoItem.ID> = []

    // In-memory set to track deleted item IDs (items that should be hidden)
    private(set) var deletedItemIDs: Set<TodoItem.ID> = []

    // Computed property to get displayed active todos
    var displayedActiveTodos: [TodoItem] {
        // Explicitly reference both dependencies to ensure proper observation
        let allItems = repository.items
        let toggledIDs = toggledItemIDs
        let deletedIDs = deletedItemIDs

        return allItems
            .filter { item in
                // Include if: (active and not deleted) OR (done and toggled and not deleted)
                (!item.isDone && !deletedIDs.contains(item.id)) ||
                (item.isDone && toggledIDs.contains(item.id) && !deletedIDs.contains(item.id))
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

    func loadActiveTodos() {
        // Clear in-memory state
        toggledItemIDs.removeAll()
        deletedItemIDs.removeAll()
    }

    func refresh() async {
        // Clear in-memory state
        loadActiveTodos()
    }

    init(repository: TodoRepository<S, G>, service: GitHubService?) {
        self.repository = repository
        self.service = service
    }

    func handleToggle(_ item: TodoItem) {
        // Always show alert if item has a linked GitHub issue
        if item.gitHubIssueUrl != nil {
            pendingToggleItem = item
            showStateChangeAlert = true
        } else {
            // Toggle the in-memory state
            if toggledItemIDs.contains(item.id) {
                toggledItemIDs.remove(item.id)
            } else {
                toggledItemIDs.insert(item.id)
            }
            // Update repository
            repository.toggleDone(item)
        }
    }

    func toggleWithIssueUpdate(stateReason: String?) {
        guard let item = pendingToggleItem else { return }
        // Toggle the in-memory state
        if toggledItemIDs.contains(item.id) {
            toggledItemIDs.remove(item.id)
        } else {
            toggledItemIDs.insert(item.id)
        }
        // Update repository
        repository.toggleDone(item)
        pendingToggleItem = nil
    }

    func updateIssueStateForToggle(item: TodoItem, stateReason: String?) async throws {
        guard let service = service,
            let issueNumber = item.gitHubIssueNumber
        else {
            return
        }

        // Determine new state BEFORE toggling
        let newState = item.isDone ? "open" : "closed"

        _ = try await service.issueCreator.updateIssueState(
            owner: service.repositorySettings.owner,
            repo: service.repositorySettings.repo,
            issueNumber: issueNumber,
            state: newState,
            stateReason: stateReason
        )
        logger.debug(
            "Updated issue #\(issueNumber) to \(newState) with reason: \(stateReason ?? "nil")")
    }

    func toggleWithoutIssueUpdate() {
        guard let item = pendingToggleItem else { return }
        // Toggle the in-memory state
        if toggledItemIDs.contains(item.id) {
            toggledItemIDs.remove(item.id)
        } else {
            toggledItemIDs.insert(item.id)
        }
        // Update repository
        repository.toggleDone(item)
        pendingToggleItem = nil
    }

    func handleDelete(_ item: TodoItem) {
        // Show alert only if item has a linked GitHub issue and is not done
        if item.gitHubIssueUrl != nil && !item.isDone {
            pendingDeleteItem = item
            showDeleteAlert = true
        } else {
            // Update repository immediately, but hide from view
            repository.delete(item)
            deletedItemIDs.insert(item.id)
        }
    }

    func deleteWithoutClosingIssue() {
        guard let item = pendingDeleteItem else { return }
        // Update repository immediately, but hide from view
        repository.delete(item)
        deletedItemIDs.insert(item.id)
        pendingDeleteItem = nil
    }

    func deleteAndCloseIssue(stateReason: String) {
        guard let item = pendingDeleteItem else { return }
        // Update repository immediately, but hide from view
        repository.delete(item)
        deletedItemIDs.insert(item.id)
        pendingDeleteItem = nil
    }

    func closeIssueForDelete(item: TodoItem, stateReason: String) async throws {
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
        logger.debug("Closed issue #\(issueNumber) as \(stateReason) before deleting todo")
    }

    func createAddEditModel(editingItem: TodoItem? = nil) -> AddEditTodoModel<S, G> {
        AddEditTodoModel(
            repository: repository,
            repositorySettings: service?.repositorySettings,
            service: service,
            editingItem: editingItem
        )
    }

    func createDoneListModel() -> DoneTodoListModel<S, G> {
        DoneTodoListModel(
            repository: repository,
            repositorySettings: service?.repositorySettings,
            service: service
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

    public var body: some View {
        Group {
            if model.displayedActiveTodos.isEmpty {
                ContentUnavailableView(
                    "No Active Todos",
                    systemImage: "checklist",
                    description: Text("Add a new todo to get started")
                )
            } else {
                List {
                    ForEach(model.displayedActiveTodos) { item in
                        NavigationLink {
                            AddEditTodoView(model: model.createAddEditModel(editingItem: item))
                        } label: {
                            TodoRowView(
                                model: TodoRowModel(
                                    item: item,
                                    onToggle: { model.handleToggle(item) },
                                    effectiveDoneState: model.effectiveDoneState(for: item)
                                )
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    model.handleDelete(item)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                    .onDelete { indexSet in
                        withAnimation {
                            for index in indexSet {
                                let item = model.displayedActiveTodos[index]
                                model.handleDelete(item)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            model.loadActiveTodos()
        }
        .refreshable {
            await model.refresh()
        }
        .toolbar {
            #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            #endif
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
                    DoneTodoListView(model: model.createDoneListModel())
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
        .sheet(isPresented: $model.isShowingAddView) {
            AddEditTodoView(model: model.createAddEditModel())
        }
        .alert(
            model.pendingToggleItem?.isDone == true
                ? "Reopen GitHub Issue?" : "Close GitHub Issue?",
            isPresented: $model.showStateChangeAlert
        ) {
            if model.pendingToggleItem?.isDone == false {
                Button("Check & Close as Completed") {
                    if let item = model.pendingToggleItem {
                        model.toggleWithIssueUpdate(stateReason: "completed")
                        Task {
                            do {
                                try await model.updateIssueStateForToggle(
                                    item: item, stateReason: "completed")
                            } catch {
                                logger.error("Failed to update GitHub issue state: \(error)")
                            }
                        }
                    }
                }
                Button("Check & Close as Not Planned") {
                    if let item = model.pendingToggleItem {
                        model.toggleWithIssueUpdate(stateReason: "not_planned")
                        Task {
                            do {
                                try await model.updateIssueStateForToggle(
                                    item: item, stateReason: "not_planned")
                            } catch {
                                logger.error("Failed to update GitHub issue state: \(error)")
                            }
                        }
                    }
                }
                Button("Check & Close as Duplicate") {
                    if let item = model.pendingToggleItem {
                        model.toggleWithIssueUpdate(stateReason: "duplicate")
                        Task {
                            do {
                                try await model.updateIssueStateForToggle(
                                    item: item, stateReason: "duplicate")
                            } catch {
                                logger.error("Failed to update GitHub issue state: \(error)")
                            }
                        }
                    }
                }
                Button("Check Only") {
                    model.toggleWithoutIssueUpdate()
                }
            } else {
                Button("Uncheck & Reopen") {
                    if let item = model.pendingToggleItem {
                        model.toggleWithIssueUpdate(stateReason: nil)
                        Task {
                            do {
                                try await model.updateIssueStateForToggle(
                                    item: item, stateReason: nil)
                            } catch {
                                logger.error("Failed to update GitHub issue state: \(error)")
                            }
                        }
                    }
                }
                Button("Uncheck Only") {
                    model.toggleWithoutIssueUpdate()
                }
            }
            Button("Cancel", role: .cancel) {
                model.pendingToggleItem = nil
            }
        } message: {
            if let item = model.pendingToggleItem {
                if item.isDone {
                    Text("This will reopen the linked GitHub issue.")
                } else {
                    Text("This will close the linked GitHub issue. Choose a reason:")
                }
            }
        }
        .alert("Delete Todo?", isPresented: $model.showDeleteAlert) {
            Button("Delete & Close as Completed") {
                if let item = model.pendingDeleteItem {
                    Task {
                        do {
                            try await model.closeIssueForDelete(
                                item: item, stateReason: "completed")
                        } catch {
                            logger.error("Failed to close GitHub issue: \(error)")
                        }
                    }
                    model.deleteAndCloseIssue(stateReason: "completed")
                }
            }
            Button("Delete & Close as Not Planned") {
                if let item = model.pendingDeleteItem {
                    Task {
                        do {
                            try await model.closeIssueForDelete(
                                item: item, stateReason: "not_planned")
                        } catch {
                            logger.error("Failed to close GitHub issue: \(error)")
                        }
                    }
                    model.deleteAndCloseIssue(stateReason: "not_planned")
                }
            }
            Button("Delete & Close as Duplicate") {
                if let item = model.pendingDeleteItem {
                    Task {
                        do {
                            try await model.closeIssueForDelete(
                                item: item, stateReason: "duplicate")
                        } catch {
                            logger.error("Failed to close GitHub issue: \(error)")
                        }
                    }
                    model.deleteAndCloseIssue(stateReason: "duplicate")
                }
            }
            Button("Delete Only") {
                model.deleteWithoutClosingIssue()
            }
            Button("Cancel", role: .cancel) {
                model.pendingDeleteItem = nil
            }
        } message: {
            Text("Do you want to close the linked GitHub issue? Choose a reason:")
        }
        #if os(iOS)
            .environment(\.editMode, $model.editMode)
        #endif
    }
}
