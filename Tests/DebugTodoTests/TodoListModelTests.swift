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
    func handleToggleWithoutGitHubIssue() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        await repository.addWithoutIssue(title: "Test", detail: "")
        await model.loadActiveTodos()  // Load the todo into cache
        let item = model.displayedActiveTodos.first!

        await model.handleToggle(item)

        #expect(model.showStateChangeAlert == false)
        #expect(repository.doneTodos.count == 1)
        #expect(repository.activeTodos.isEmpty)
        // Item should be tracked as toggled in-memory
        #expect(model.toggledItemIDs.contains(item.id))
        // Item should still appear in displayed list with toggled state
        #expect(model.displayedActiveTodos.count == 1)
        // Get the current displayed item (from doneTodos now)
        let displayedItem = model.displayedActiveTodos.first!
        #expect(model.effectiveDoneState(for: displayedItem) == true)
    }

    @Test("Handle toggle with GitHub issue shows alert")
    func handleToggleWithGitHubIssueShowsAlert() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        await repository.addWithoutIssue(title: "Test", detail: "")
        let item = repository.activeTodos.first!
        await repository.updateGitHubIssueUrl(for: item.id, url: "https://github.com/test/repo/issues/1")
        let updatedItem = repository.activeTodos.first!

        await model.handleToggle(updatedItem)

        #expect(model.showStateChangeAlert == true)
        #expect(model.pendingToggleItem?.id == item.id)
        #expect(repository.doneTodos.isEmpty)
    }

    @Test("Toggle with issue update completes toggle")
    func toggleWithIssueUpdate() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        await repository.addWithoutIssue(title: "Test", detail: "")
        let item = repository.activeTodos.first!
        await repository.updateGitHubIssueUrl(for: item.id, url: "https://github.com/test/repo/issues/1")
        let updatedItem = repository.activeTodos.first!

        model.pendingToggleItem = updatedItem
        await model.toggleWithIssueUpdate(stateReason: "completed")

        #expect(model.pendingToggleItem == nil)
        #expect(repository.doneTodos.count == 1)
    }

    @Test("Toggle without issue update completes toggle")
    func toggleWithoutIssueUpdate() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        await repository.addWithoutIssue(title: "Test", detail: "")
        let item = repository.activeTodos.first!
        await repository.updateGitHubIssueUrl(for: item.id, url: "https://github.com/test/repo/issues/1")
        let updatedItem = repository.activeTodos.first!

        model.pendingToggleItem = updatedItem
        await model.toggleWithoutIssueUpdate()

        #expect(model.pendingToggleItem == nil)
        #expect(repository.doneTodos.count == 1)
    }

    @Test("Handle delete without GitHub issue")
    func handleDeleteWithoutGitHubIssue() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        await repository.addWithoutIssue(title: "Test", detail: "")
        let item = repository.activeTodos.first!

        await model.handleDelete(item)

        #expect(model.showDeleteAlert == false)
        #expect(repository.activeTodos.isEmpty)
    }

    @Test("Handle delete with GitHub issue shows alert")
    func handleDeleteWithGitHubIssueShowsAlert() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        await repository.addWithoutIssue(title: "Test", detail: "")
        let item = repository.activeTodos.first!
        await repository.updateGitHubIssueUrl(for: item.id, url: "https://github.com/test/repo/issues/1")
        let updatedItem = repository.activeTodos.first!

        await model.handleDelete(updatedItem)

        #expect(model.showDeleteAlert == true)
        #expect(model.pendingDeleteItem?.id == item.id)
        #expect(repository.activeTodos.count == 1)
    }

    @Test("Handle delete with done item does not show alert")
    func handleDeleteWithDoneItemDoesNotShowAlert() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        await repository.addWithoutIssue(title: "Test", detail: "")
        let item = repository.activeTodos.first!
        await repository.updateGitHubIssueUrl(for: item.id, url: "https://github.com/test/repo/issues/1")
        await repository.toggleDone(item)
        let doneItem = repository.doneTodos.first!

        await model.handleDelete(doneItem)

        #expect(model.showDeleteAlert == false)
        #expect(repository.doneTodos.isEmpty)
    }

    @Test("Delete without closing issue")
    func deleteWithoutClosingIssue() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        await repository.addWithoutIssue(title: "Test", detail: "")
        let item = repository.activeTodos.first!
        await repository.updateGitHubIssueUrl(for: item.id, url: "https://github.com/test/repo/issues/1")
        let updatedItem = repository.activeTodos.first!

        model.pendingDeleteItem = updatedItem
        await model.deleteWithoutClosingIssue()

        #expect(model.pendingDeleteItem == nil)
        #expect(repository.activeTodos.isEmpty)
    }

    @Test("Delete and close issue")
    func deleteAndCloseIssue() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        await repository.addWithoutIssue(title: "Test", detail: "")
        let item = repository.activeTodos.first!
        await repository.updateGitHubIssueUrl(for: item.id, url: "https://github.com/test/repo/issues/1")
        let updatedItem = repository.activeTodos.first!

        model.pendingDeleteItem = updatedItem
        await model.deleteAndCloseIssue(stateReason: "completed")

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
    func createAddEditModelWithEditingItem() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let service = GitHubService()
        let model = TodoListModel(repository: repository, service: service)

        await repository.addWithoutIssue(title: "Test", detail: "Detail")
        let item = repository.activeTodos.first!

        let addEditModel = model.createAddEditModel(editingItem: item)

        #expect(addEditModel.editingItem?.id == item.id)
        #expect(addEditModel.title == "Test")
        #expect(addEditModel.detail == "Detail")
    }

    @Test("Done list model is initialized with service")
    func doneListModelInitializedWithService() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let service = GitHubService()
        let model = TodoListModel(repository: repository, service: service)

        #expect(model.doneListModel.service != nil)
    }

    @Test("Load active todos clears in-memory state")
    func loadActiveTodosClearsInMemoryState() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        await repository.addWithoutIssue(title: "Test", detail: "")
        let item = repository.activeTodos.first!

        await model.handleToggle(item)
        #expect(model.toggledItemIDs.contains(item.id))

        await model.loadActiveTodos()
        #expect(model.toggledItemIDs.isEmpty)
        #expect(model.displayedActiveTodos.isEmpty)
    }

    @Test("Refresh clears in-memory state")
    func refreshClearsInMemoryState() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        await repository.addWithoutIssue(title: "Test", detail: "")
        let item = repository.activeTodos.first!

        await model.handleToggle(item)
        #expect(model.toggledItemIDs.contains(item.id))

        await model.refresh()
        #expect(model.toggledItemIDs.isEmpty)
        #expect(model.displayedActiveTodos.isEmpty)
    }

    @Test("Effective done state reflects in-memory toggle")
    func effectiveDoneStateReflectsInMemoryToggle() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        await repository.addWithoutIssue(title: "Test", detail: "")
        let item = repository.activeTodos.first!

        #expect(model.effectiveDoneState(for: item) == false)

        await model.handleToggle(item)
        let displayedItem = model.displayedActiveTodos.first!
        #expect(model.effectiveDoneState(for: displayedItem) == true)
    }

    @Test("Handle delete hides item from display")
    func handleDeleteHidesItemFromDisplay() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        await repository.addWithoutIssue(title: "Test", detail: "")
        await model.loadActiveTodos()
        let item = model.displayedActiveTodos.first!

        await model.handleDelete(item)

        #expect(repository.activeTodos.isEmpty)
        #expect(model.deletedItemIDs.contains(item.id))
        #expect(model.displayedActiveTodos.isEmpty)
    }

    @Test("Toggled item remains visible in active list with checked state")
    func toggledItemRemainsVisibleInActiveList() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        await repository.addWithoutIssue(title: "Test", detail: "")
        await model.loadActiveTodos()
        let item = model.displayedActiveTodos.first!

        #expect(item.isDone == false)
        #expect(model.effectiveDoneState(for: item) == false)

        // Toggle the item
        await model.handleToggle(item)

        // Item should still be in displayed list
        #expect(model.displayedActiveTodos.count == 1)
        // Repository should be updated
        #expect(repository.doneTodos.count == 1)
        #expect(repository.activeTodos.isEmpty)
        // Get the displayed item (now from doneTodos)
        let displayedItem = model.displayedActiveTodos.first!
        // Effective state should show as done
        #expect(model.effectiveDoneState(for: displayedItem) == true)
        // Item should be in toggled set
        #expect(model.toggledItemIDs.contains(item.id))
    }

    @Test("Multiple toggles on same item work correctly")
    func multipleTogglesOnSameItem() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = TodoListModel(repository: repository, service: nil)

        await repository.addWithoutIssue(title: "Test", detail: "")
        await model.loadActiveTodos()
        let item = model.displayedActiveTodos.first!
        let itemId = item.id

        // First toggle: active -> done
        await model.handleToggle(item)
        #expect(model.displayedActiveTodos.count == 1)
        // Get the displayed item (which should still be showing)
        let displayedItem1 = model.displayedActiveTodos.first!
        #expect(displayedItem1.id == itemId)
        // Item is now in doneTodos (isDone=true), so effective state is true
        #expect(model.effectiveDoneState(for: displayedItem1) == true)
        #expect(repository.doneTodos.count == 1)

        // Second toggle: done -> active (toggle the displayed item)
        await model.handleToggle(displayedItem1)
        #expect(model.displayedActiveTodos.count == 1)
        let displayedItem2 = model.displayedActiveTodos.first!
        #expect(displayedItem2.id == itemId)
        // Item is now in activeTodos (isDone=false), so effective state is false
        #expect(model.effectiveDoneState(for: displayedItem2) == false)
        #expect(repository.activeTodos.count == 1)
    }

    @Test("Toggled items preserve their position in the list")
    func toggledItemsPreservePosition() async throws {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())

        // Add items through repository to ensure proper initialization
        await repository.addWithoutIssue(title: "First", detail: "")
        await repository.addWithoutIssue(title: "Second", detail: "")
        await repository.addWithoutIssue(title: "Third", detail: "")

        let model = TodoListModel(repository: repository, service: nil)

        await model.loadActiveTodos()
        let items = model.displayedActiveTodos

        // Verify initial order (newest first based on createdAt)
        #expect(items.count == 3)
        #expect(items[0].title == "Third")
        #expect(items[1].title == "Second")
        #expect(items[2].title == "First")

        // Toggle the middle item (Second)
        let secondItem = items[1]
        await model.handleToggle(secondItem)

        let displayedAfterToggle = model.displayedActiveTodos
        #expect(displayedAfterToggle.count == 3)

        // Order should be preserved: Third, Second (toggled), First
        #expect(displayedAfterToggle[0].title == "Third")
        #expect(displayedAfterToggle[1].title == "Second")
        #expect(displayedAfterToggle[2].title == "First")

        // Second item should be marked as done
        #expect(displayedAfterToggle[1].isDone == true)
    }
}
