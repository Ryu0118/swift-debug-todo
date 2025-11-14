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
        // Get the displayed item (now from activeTodos)
        let displayedItem = model.displayedDoneTodos.first!
        #expect(model.effectiveDoneState(for: displayedItem) == false)
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
        let displayedItem = model.displayedDoneTodos.first!
        #expect(model.effectiveDoneState(for: displayedItem) == false)
    }

    @Test("Handle delete hides item from display")
    func handleDeleteHidesItemFromDisplay() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.toggleDone(item)

        model.loadDoneTodos()
        let doneItem = model.displayedDoneTodos.first!
        model.handleDelete(doneItem)

        #expect(repository.doneTodos.isEmpty)
        #expect(model.deletedItemIDs.contains(doneItem.id))
        #expect(model.displayedDoneTodos.isEmpty)
    }

    @Test("Unchecked item remains visible in done list with unchecked state")
    func uncheckedItemRemainsVisibleInDoneList() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.toggleDone(item)

        model.loadDoneTodos()
        let doneItem = model.displayedDoneTodos.first!

        #expect(doneItem.isDone == true)
        #expect(model.effectiveDoneState(for: doneItem) == true)

        // Uncheck the item
        model.handleReopen(doneItem)

        // Item should still be in displayed list
        #expect(model.displayedDoneTodos.count == 1)
        // Repository should be updated
        #expect(repository.activeTodos.count == 1)
        #expect(repository.doneTodos.isEmpty)
        // Get the displayed item (now from activeTodos)
        let displayedItem = model.displayedDoneTodos.first!
        // Effective state should show as not done
        #expect(model.effectiveDoneState(for: displayedItem) == false)
        // Item should be in toggled set
        #expect(model.toggledItemIDs.contains(doneItem.id))
    }

    @Test("Multiple toggles on done item work correctly")
    func multipleTogglesOnDoneItem() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.toggleDone(item)

        model.loadDoneTodos()
        let doneItem = model.displayedDoneTodos.first!
        let itemId = doneItem.id

        // First toggle: done -> active
        model.handleReopen(doneItem)
        #expect(model.displayedDoneTodos.count == 1)
        // Get the displayed item (which should still be showing)
        let displayedItem1 = model.displayedDoneTodos.first!
        #expect(displayedItem1.id == itemId)
        // Item is now in activeTodos (isDone=false), so effective state is false
        #expect(model.effectiveDoneState(for: displayedItem1) == false)
        #expect(repository.activeTodos.count == 1)

        // Second toggle: active -> done (toggle the displayed item)
        model.handleReopen(displayedItem1)
        #expect(model.displayedDoneTodos.count == 1)
        let displayedItem2 = model.displayedDoneTodos.first!
        #expect(displayedItem2.id == itemId)
        // Item is now in doneTodos (isDone=true), so effective state is true
        #expect(model.effectiveDoneState(for: displayedItem2) == true)
        #expect(repository.doneTodos.count == 1)
    }

    @Test("Toggled items preserve their position in done list")
    func toggledItemsPreservePositionInDoneList() async throws {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())

        // Add items and mark them as done through repository
        repository.add(title: "First", detail: "", createIssue: false)
        repository.add(title: "Second", detail: "", createIssue: false)
        repository.add(title: "Third", detail: "", createIssue: false)

        // Mark all as done
        for item in repository.activeTodos {
            repository.toggleDone(item)
        }

        let model = DoneTodoListModel(repository: repository)

        model.loadDoneTodos()
        let items = model.displayedDoneTodos

        // Verify initial order (newest createdAt first)
        #expect(items.count == 3)
        #expect(items[0].title == "Third")
        #expect(items[1].title == "Second")
        #expect(items[2].title == "First")

        // Toggle the middle item (reopen it)
        let middleItem = items[1]
        model.handleReopen(middleItem)

        let displayedAfterToggle = model.displayedDoneTodos
        #expect(displayedAfterToggle.count == 3)

        // Order should be preserved: Third, Second (toggled), First
        #expect(displayedAfterToggle[0].title == "Third")
        #expect(displayedAfterToggle[1].title == "Second")
        #expect(displayedAfterToggle[2].title == "First")

        // Middle item should be marked as not done
        #expect(displayedAfterToggle[1].isDone == false)
    }

    @Test("Single done item unchecked remains visible")
    func singleDoneItemUncheckedRemainsVisible() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        // Add one done item
        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.toggleDone(item)

        model.loadDoneTodos()
        #expect(model.displayedDoneTodos.count == 1)

        let doneItem = model.displayedDoneTodos.first!

        // Uncheck it
        model.handleReopen(doneItem)

        // Should still be displayed
        #expect(model.displayedDoneTodos.count == 1, "Item should remain visible after unchecking")
        #expect(model.toggledItemIDs.contains(doneItem.id), "Item should be in toggledItemIDs")

        let displayedItem = model.displayedDoneTodos.first!
        #expect(displayedItem.id == doneItem.id, "Same item should be displayed")
        #expect(displayedItem.isDone == false, "Item should be marked as not done in repository")
    }
}
