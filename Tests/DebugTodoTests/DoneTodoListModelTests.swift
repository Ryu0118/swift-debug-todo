import Foundation
import Testing

@testable import DebugTodo

@Suite("DoneTodoListModel Tests")
@MainActor
struct DoneTodoListModelTests {

    @Test("Initialize model")
    func initialize() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        #expect(model.showDeleteAllAlert == false)
        #expect(model.selectedTodoIDs.isEmpty)
        #expect(model.showReopenAlert == false)
        #expect(model.pendingReopenItem == nil)
    }

    @Test("Initialize model with repository settings")
    func initializeWithRepositorySettings() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let settings = GitHubRepositorySettings(
            owner: "test", repo: "repo", showConfirmationAlert: true)
        let model = DoneTodoListModel(repository: repository, repositorySettings: settings)

        #expect(model.repositorySettings?.owner == "test")
        #expect(model.repositorySettings?.repo == "repo")
    }

    @Test("Initialize model with service")
    func initializeWithService() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let service = GitHubService()
        let model = DoneTodoListModel(repository: repository, service: service)

        #expect(model.service != nil)
    }

    @Test("Delete all done todos")
    func deleteAllDoneTodos() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        // Add some done todos
        repository.add(title: "Todo 1", detail: "", createIssue: false)
        repository.add(title: "Todo 2", detail: "", createIssue: false)
        repository.add(title: "Todo 3", detail: "", createIssue: false)

        // Mark them as done
        for todo in repository.activeTodos {
            repository.toggleDone(todo)
        }

        model.loadDoneTodos()  // Load into cache
        #expect(repository.doneTodos.count == 3)

        model.deleteAllDoneTodos()

        #expect(repository.doneTodos.isEmpty)
    }

    @Test("Delete selected todos")
    func deleteSelectedTodos() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        // Add and mark as done
        repository.add(title: "Todo 1", detail: "", createIssue: false)
        repository.add(title: "Todo 2", detail: "", createIssue: false)
        repository.add(title: "Todo 3", detail: "", createIssue: false)

        for todo in repository.activeTodos {
            repository.toggleDone(todo)
        }

        model.loadDoneTodos()  // Load into cache
        let doneTodos = model.displayedDoneTodos
        model.selectedTodoIDs = Set([doneTodos[0].id, doneTodos[2].id])

        model.deleteSelectedTodos()

        #expect(repository.doneTodos.count == 1)
        #expect(repository.doneTodos.first?.title == "Todo 2")
        #expect(model.selectedTodoIDs.isEmpty)
    }

    @Test("Handle reopen without GitHub issue")
    func handleReopenWithoutGitHubIssue() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.toggleDone(item)

        model.loadDoneTodos()  // Load into cache
        let doneItem = model.displayedDoneTodos.first!
        model.handleReopen(doneItem)

        #expect(model.showReopenAlert == false)
        #expect(repository.activeTodos.count == 1)
        #expect(repository.doneTodos.isEmpty)
        // Item should be tracked as toggled in-memory
        #expect(model.toggledItemIDs.contains(doneItem.id))
        // Item should still appear in displayed list with toggled state
        #expect(model.displayedDoneTodos.count == 1)
        #expect(model.effectiveDoneState(for: doneItem) == false)
    }

    @Test("Handle reopen with GitHub issue shows alert")
    func handleReopenWithGitHubIssueShowsAlert() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.updateGitHubIssueUrl(for: item.id, url: "https://github.com/test/repo/issues/1")
        repository.toggleDone(item)

        let doneItem = repository.doneTodos.first!
        model.handleReopen(doneItem)

        #expect(model.showReopenAlert == true)
        #expect(model.pendingReopenItem?.id == doneItem.id)
        #expect(repository.activeTodos.isEmpty)
    }

    @Test("Reopen without issue update completes reopen")
    func reopenWithoutIssueUpdate() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.updateGitHubIssueUrl(for: item.id, url: "https://github.com/test/repo/issues/1")
        repository.toggleDone(item)

        let doneItem = repository.doneTodos.first!
        model.pendingReopenItem = doneItem
        model.reopenWithoutIssueUpdate()

        #expect(model.pendingReopenItem == nil)
        #expect(repository.activeTodos.count == 1)
        #expect(repository.doneTodos.isEmpty)
    }

    @Test("Reopen with issue update completes reopen")
    func reopenWithIssueUpdate() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.updateGitHubIssueUrl(for: item.id, url: "https://github.com/test/repo/issues/1")
        repository.toggleDone(item)

        let doneItem = repository.doneTodos.first!
        model.pendingReopenItem = doneItem
        model.reopenWithIssueUpdate()

        #expect(model.pendingReopenItem == nil)
        #expect(repository.activeTodos.count == 1)
        #expect(repository.doneTodos.isEmpty)
    }

    @Test("Selected todo IDs can be modified")
    func selectedTodoIDsCanBeModified() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        let id1 = UUID()
        let id2 = UUID()

        model.selectedTodoIDs.insert(id1)
        model.selectedTodoIDs.insert(id2)

        #expect(model.selectedTodoIDs.count == 2)
        #expect(model.selectedTodoIDs.contains(id1))
        #expect(model.selectedTodoIDs.contains(id2))

        model.selectedTodoIDs.removeAll()
        #expect(model.selectedTodoIDs.isEmpty)
    }

    @Test("Show delete all alert flag can be toggled")
    func showDeleteAllAlertCanBeToggled() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        model.showDeleteAllAlert = true
        #expect(model.showDeleteAllAlert == true)

        model.showDeleteAllAlert = false
        #expect(model.showDeleteAllAlert == false)
    }

    @Test("Show reopen alert flag can be toggled")
    func showReopenAlertCanBeToggled() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        model.showReopenAlert = true
        #expect(model.showReopenAlert == true)

        model.showReopenAlert = false
        #expect(model.showReopenAlert == false)
    }

    @Test("Create add edit model for editing")
    func createAddEditModelForEditing() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let service = GitHubService()
        let model = DoneTodoListModel(repository: repository, service: service)

        repository.add(title: "Test", detail: "Detail", createIssue: false)
        repository.toggleDone(repository.activeTodos.first!)
        let doneItem = repository.doneTodos.first!

        let addEditModel = model.createAddEditModel(editingItem: doneItem)

        #expect(addEditModel.editingItem?.id == doneItem.id)
        #expect(addEditModel.title == "Test")
        #expect(addEditModel.detail == "Detail")
        #expect(addEditModel.service != nil)
    }

    @Test("Pending reopen item can be set and cleared")
    func pendingReopenItemCanBeSetAndCleared() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        let item = TodoItem(title: "Test", detail: "")
        model.pendingReopenItem = item

        #expect(model.pendingReopenItem?.id == item.id)

        model.pendingReopenItem = nil
        #expect(model.pendingReopenItem == nil)
    }

    @Test("Delete all does not affect active todos")
    func deleteAllDoesNotAffectActiveTodos() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        // Add active todos
        repository.add(title: "Active 1", detail: "", createIssue: false)
        repository.add(title: "Active 2", detail: "", createIssue: false)

        // Add done todos
        repository.add(title: "Done 1", detail: "", createIssue: false)
        repository.toggleDone(repository.activeTodos.last!)

        model.loadDoneTodos()  // Load into cache
        #expect(repository.activeTodos.count == 2)
        #expect(repository.doneTodos.count == 1)

        model.deleteAllDoneTodos()

        #expect(repository.activeTodos.count == 2)
        #expect(repository.doneTodos.isEmpty)
    }

    @Test("Load done todos clears in-memory state")
    func loadDoneTodosClearsInMemoryState() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.toggleDone(item)

        let doneItem = repository.doneTodos.first!
        model.handleReopen(doneItem)
        #expect(model.toggledItemIDs.contains(doneItem.id))

        model.loadDoneTodos()
        #expect(model.toggledItemIDs.isEmpty)
        #expect(model.displayedDoneTodos.isEmpty)
    }

    @Test("Refresh clears in-memory state")
    func refreshClearsInMemoryState() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.toggleDone(item)

        let doneItem = repository.doneTodos.first!
        model.handleReopen(doneItem)
        #expect(model.toggledItemIDs.contains(doneItem.id))

        await model.refresh()
        #expect(model.toggledItemIDs.isEmpty)
        #expect(model.displayedDoneTodos.isEmpty)
    }

    @Test("Effective done state reflects in-memory toggle")
    func effectiveDoneStateReflectsInMemoryToggle() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.toggleDone(item)

        let doneItem = repository.doneTodos.first!
        #expect(model.effectiveDoneState(for: doneItem) == true)

        model.handleReopen(doneItem)
        #expect(model.effectiveDoneState(for: doneItem) == false)
    }

    @Test("Handle delete hides item from display")
    func handleDeleteHidesItemFromDisplay() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.toggleDone(item)

        let doneItem = repository.doneTodos.first!
        model.handleDelete(doneItem)

        #expect(repository.doneTodos.isEmpty)
        #expect(model.deletedItemIDs.contains(doneItem.id))
        #expect(model.displayedDoneTodos.isEmpty)
    }
}
