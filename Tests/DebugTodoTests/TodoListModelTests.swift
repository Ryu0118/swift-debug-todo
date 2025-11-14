import Foundation
import Testing

@testable import DebugTodo

@Suite("TodoListModel Tests")
@MainActor
struct TodoListModelTests {

    @Test("Initialize model with repository")
    func initialize() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        #expect(model.repository.activeTodos.isEmpty)
        #expect(model.isShowingAddView == false)
        #expect(model.showStateChangeAlert == false)
        #expect(model.pendingToggleItem == nil)
        #expect(model.showDeleteAlert == false)
        #expect(model.pendingDeleteItem == nil)
    }

    @Test("Initialize model with GitHub service")
    func initializeWithService() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let service = GitHubService()
        let model = TodoListModel(repository: repository, service: service)

        #expect(model.service != nil)
    }

    @Test("Handle toggle without GitHub issue")
    func handleToggleWithoutGitHubIssue() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        repository.add(title: "Test", detail: "", createIssue: false)
        model.loadActiveTodos()  // Load the todo into cache
        let item = model.displayedActiveTodos.first!

        model.handleToggle(item)

        #expect(model.showStateChangeAlert == false)
        #expect(repository.doneTodos.count == 1)
        #expect(repository.activeTodos.isEmpty)
        // Item should be tracked as toggled in-memory
        #expect(model.toggledItemIDs.contains(item.id))
        // Item should still appear in displayed list with toggled state
        #expect(model.displayedActiveTodos.count == 1)
        #expect(model.effectiveDoneState(for: item) == true)
    }

    @Test("Handle toggle with GitHub issue shows alert")
    func handleToggleWithGitHubIssueShowsAlert() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.updateGitHubIssueUrl(for: item.id, url: "https://github.com/test/repo/issues/1")
        let updatedItem = repository.activeTodos.first!

        model.handleToggle(updatedItem)

        #expect(model.showStateChangeAlert == true)
        #expect(model.pendingToggleItem?.id == item.id)
        #expect(repository.doneTodos.isEmpty)
    }

    @Test("Toggle with issue update completes toggle")
    func toggleWithIssueUpdate() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.updateGitHubIssueUrl(for: item.id, url: "https://github.com/test/repo/issues/1")
        let updatedItem = repository.activeTodos.first!

        model.pendingToggleItem = updatedItem
        model.toggleWithIssueUpdate(stateReason: "completed")

        #expect(model.pendingToggleItem == nil)
        #expect(repository.doneTodos.count == 1)
    }

    @Test("Toggle without issue update completes toggle")
    func toggleWithoutIssueUpdate() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.updateGitHubIssueUrl(for: item.id, url: "https://github.com/test/repo/issues/1")
        let updatedItem = repository.activeTodos.first!

        model.pendingToggleItem = updatedItem
        model.toggleWithoutIssueUpdate()

        #expect(model.pendingToggleItem == nil)
        #expect(repository.doneTodos.count == 1)
    }

    @Test("Handle delete without GitHub issue")
    func handleDeleteWithoutGitHubIssue() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!

        model.handleDelete(item)

        #expect(model.showDeleteAlert == false)
        #expect(repository.activeTodos.isEmpty)
    }

    @Test("Handle delete with GitHub issue shows alert")
    func handleDeleteWithGitHubIssueShowsAlert() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.updateGitHubIssueUrl(for: item.id, url: "https://github.com/test/repo/issues/1")
        let updatedItem = repository.activeTodos.first!

        model.handleDelete(updatedItem)

        #expect(model.showDeleteAlert == true)
        #expect(model.pendingDeleteItem?.id == item.id)
        #expect(repository.activeTodos.count == 1)
    }

    @Test("Handle delete with done item does not show alert")
    func handleDeleteWithDoneItemDoesNotShowAlert() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.updateGitHubIssueUrl(for: item.id, url: "https://github.com/test/repo/issues/1")
        repository.toggleDone(item)
        let doneItem = repository.doneTodos.first!

        model.handleDelete(doneItem)

        #expect(model.showDeleteAlert == false)
        #expect(repository.doneTodos.isEmpty)
    }

    @Test("Delete without closing issue")
    func deleteWithoutClosingIssue() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.updateGitHubIssueUrl(for: item.id, url: "https://github.com/test/repo/issues/1")
        let updatedItem = repository.activeTodos.first!

        model.pendingDeleteItem = updatedItem
        model.deleteWithoutClosingIssue()

        #expect(model.pendingDeleteItem == nil)
        #expect(repository.activeTodos.isEmpty)
    }

    @Test("Delete and close issue")
    func deleteAndCloseIssue() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!
        repository.updateGitHubIssueUrl(for: item.id, url: "https://github.com/test/repo/issues/1")
        let updatedItem = repository.activeTodos.first!

        model.pendingDeleteItem = updatedItem
        model.deleteAndCloseIssue(stateReason: "completed")

        #expect(model.pendingDeleteItem == nil)
        #expect(repository.activeTodos.isEmpty)
    }

    @Test("Create add edit model")
    func createAddEditModel() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let service = GitHubService()
        let model = TodoListModel(repository: repository, service: service)

        let addEditModel = model.createAddEditModel()

        #expect(addEditModel.editingItem == nil)
        #expect(addEditModel.service != nil)
    }

    @Test("Create add edit model with editing item")
    func createAddEditModelWithEditingItem() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let service = GitHubService()
        let model = TodoListModel(repository: repository, service: service)

        repository.add(title: "Test", detail: "Detail", createIssue: false)
        let item = repository.activeTodos.first!

        let addEditModel = model.createAddEditModel(editingItem: item)

        #expect(addEditModel.editingItem?.id == item.id)
        #expect(addEditModel.title == "Test")
        #expect(addEditModel.detail == "Detail")
    }

    @Test("Create done list model")
    func createDoneListModel() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let service = GitHubService()
        let model = TodoListModel(repository: repository, service: service)

        let doneListModel = model.createDoneListModel()

        #expect(doneListModel.service != nil)
    }

    @Test("Load active todos clears in-memory state")
    func loadActiveTodosClearsInMemoryState() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!

        model.handleToggle(item)
        #expect(model.toggledItemIDs.contains(item.id))

        model.loadActiveTodos()
        #expect(model.toggledItemIDs.isEmpty)
        #expect(model.displayedActiveTodos.isEmpty)
    }

    @Test("Refresh clears in-memory state")
    func refreshClearsInMemoryState() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!

        model.handleToggle(item)
        #expect(model.toggledItemIDs.contains(item.id))

        await model.refresh()
        #expect(model.toggledItemIDs.isEmpty)
        #expect(model.displayedActiveTodos.isEmpty)
    }

    @Test("Effective done state reflects in-memory toggle")
    func effectiveDoneStateReflectsInMemoryToggle() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        repository.add(title: "Test", detail: "", createIssue: false)
        let item = repository.activeTodos.first!

        #expect(model.effectiveDoneState(for: item) == false)

        model.handleToggle(item)
        #expect(model.effectiveDoneState(for: item) == true)
    }

    @Test("Handle delete hides item from display")
    func handleDeleteHidesItemFromDisplay() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        repository.add(title: "Test", detail: "", createIssue: false)
        model.loadActiveTodos()
        let item = model.displayedActiveTodos.first!

        model.handleDelete(item)

        #expect(repository.activeTodos.isEmpty)
        #expect(model.deletedItemIDs.contains(item.id))
        #expect(model.displayedActiveTodos.isEmpty)
    }

    @Test("Toggled item remains visible in active list with checked state")
    func toggledItemRemainsVisibleInActiveList() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        repository.add(title: "Test", detail: "", createIssue: false)
        model.loadActiveTodos()
        let item = model.displayedActiveTodos.first!

        #expect(item.isDone == false)
        #expect(model.effectiveDoneState(for: item) == false)

        // Toggle the item
        model.handleToggle(item)

        // Item should still be in displayed list
        #expect(model.displayedActiveTodos.count == 1)
        // Repository should be updated
        #expect(repository.doneTodos.count == 1)
        #expect(repository.activeTodos.isEmpty)
        // Effective state should show as done
        #expect(model.effectiveDoneState(for: item) == true)
        // Item should be in toggled set
        #expect(model.toggledItemIDs.contains(item.id))
    }

    @Test("Multiple toggles on same item work correctly")
    func multipleTogglesOnSameItem() {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        repository.add(title: "Test", detail: "", createIssue: false)
        model.loadActiveTodos()
        let item = model.displayedActiveTodos.first!
        let itemId = item.id

        // First toggle: active -> done
        model.handleToggle(item)
        #expect(model.displayedActiveTodos.count == 1)
        // Get the displayed item (which should still be showing)
        let displayedItem1 = model.displayedActiveTodos.first!
        #expect(displayedItem1.id == itemId)
        #expect(model.effectiveDoneState(for: displayedItem1) == true)
        #expect(repository.doneTodos.count == 1)

        // Second toggle: done -> active (toggle the displayed item)
        model.handleToggle(displayedItem1)
        #expect(model.displayedActiveTodos.count == 1)
        let displayedItem2 = model.displayedActiveTodos.first!
        #expect(displayedItem2.id == itemId)
        #expect(model.effectiveDoneState(for: displayedItem2) == false)
        #expect(repository.activeTodos.count == 1)
    }
}
