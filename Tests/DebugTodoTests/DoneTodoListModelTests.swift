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

        #expect(model.deleteAllAlert == .dismissed)
        #expect(model.toggleAlert == .dismissed)
        #expect(model.todosDataState.value == nil)
        #expect(model.issueOperationState.isInProgress == false)
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
        let issueOperationService = GitHubIssueOperationService(service: service)
        let model = DoneTodoListModel(
            repository: repository, issueOperationService: issueOperationService)

        #expect(model.issueOperationService != nil)
    }

    @Test("Delete all done todos")
    func deleteAllDoneTodos() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        // Add some done todos
        await model.repository.addWithoutIssue(title: "Todo 1", detail: "")
        await model.repository.addWithoutIssue(title: "Todo 2", detail: "")
        await model.repository.addWithoutIssue(title: "Todo 3", detail: "")

        // Mark them as done
        for todo in model.repository.activeTodos {
            await model.repository.toggleDone(todo)
        }

        await model.loadDoneTodos()  // Load into cache
        #expect(model.repository.doneTodos.count == 3)

        await model.deleteAllDoneTodos()

        #expect(model.repository.doneTodos.isEmpty)
    }

    @Test("Handle reopen without GitHub issue")
    func handleReopenWithoutGitHubIssue() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        await model.repository.addWithoutIssue(title: "Test", detail: "")
        let item = model.repository.activeTodos.first!
        await model.repository.toggleDone(item)

        await model.loadDoneTodos()  // Load into cache
        let doneItem = model.displayedDoneTodos.first!.item
        await model.handleToggle(doneItem)

        #expect(model.toggleAlert == .dismissed)
        #expect(model.repository.activeTodos.count == 1)
        #expect(model.repository.doneTodos.isEmpty)
        // Item should be tracked as toggled in-memory
        #expect(model.toggledItemIDs.contains(doneItem.id))
        // Item should still appear in displayed list with toggled state
        #expect(model.displayedDoneTodos.count == 1)
        // Get the displayed item (now from activeTodos)
        let displayedItem = model.displayedDoneTodos.first!.item
        #expect(displayedItem.isDone == false)
    }

    @Test("Handle toggle with GitHub issue shows alert")
    func handleToggleWithGitHubIssueShowsAlert() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        await model.repository.addWithoutIssue(title: "Test", detail: "")
        let item = model.repository.activeTodos.first!
        await model.repository.updateGitHubIssueUrl(
            for: item.id, url: "https://github.com/test/repo/issues/1")
        await model.repository.toggleDone(item)

        await model.loadDoneTodos()
        let doneItem = model.displayedDoneTodos.first!.item
        await model.handleToggle(doneItem)

        #expect(model.toggleAlert.isPresented == true)
        #expect(model.toggleAlert.context?.item.id == doneItem.id)
        #expect(model.repository.activeTodos.isEmpty)
    }

    @Test("Toggle without issue update completes toggle")
    func toggleWithoutIssueUpdate() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        await model.repository.addWithoutIssue(title: "Test", detail: "")
        let item = model.repository.activeTodos.first!
        await model.repository.updateGitHubIssueUrl(
            for: item.id, url: "https://github.com/test/repo/issues/1")
        await model.repository.toggleDone(item)

        await model.loadDoneTodos()
        let doneItem = model.repository.doneTodos.first!
        let itemWithState = TodoItemWithIssueState(item: doneItem, issueState: .closed)
        let context = DoneTodoListModel<InMemoryStorage, MockGitHubIssueCreator>.ToggleAlertContext(
            item: doneItem, itemWithState: itemWithState)
        model.toggleAlert = .presented(context)
        await model.toggleWithoutIssueUpdate(context: context)

        #expect(model.toggleAlert == .dismissed)
        #expect(model.repository.activeTodos.count == 1)
        #expect(model.repository.doneTodos.isEmpty)
    }

    @Test("Toggle with issue update completes toggle")
    func toggleWithIssueUpdate() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        await model.repository.addWithoutIssue(title: "Test", detail: "")
        let item = model.repository.activeTodos.first!
        await model.repository.updateGitHubIssueUrl(
            for: item.id, url: "https://github.com/test/repo/issues/1")
        await model.repository.toggleDone(item)

        await model.loadDoneTodos()
        let doneItem = model.repository.doneTodos.first!
        let itemWithState = TodoItemWithIssueState(item: doneItem, issueState: .closed)
        let context = DoneTodoListModel<InMemoryStorage, MockGitHubIssueCreator>.ToggleAlertContext(
            item: doneItem, itemWithState: itemWithState)
        model.toggleAlert = .presented(context)
        await model.toggleWithIssueUpdate(context: context, stateReason: .reopened)

        #expect(model.toggleAlert == .dismissed)
        #expect(model.repository.activeTodos.count == 1)
        #expect(model.repository.doneTodos.isEmpty)
    }

    @Test("Show delete all alert flag can be toggled")
    func showDeleteAllAlertCanBeToggled() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        model.deleteAllAlert = .presented(
            DoneTodoListModel<InMemoryStorage, MockGitHubIssueCreator>.DeleteAllContext())
        #expect(model.deleteAllAlert.isPresented == true)

        model.deleteAllAlert = .dismissed
        #expect(model.deleteAllAlert.isPresented == false)
    }

    @Test("Show toggle alert flag can be toggled")
    func showToggleAlertCanBeToggled() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)
        let item = TodoItem(title: "Test", detail: "")
        let itemWithState = TodoItemWithIssueState(item: item, issueState: .closed)

        model.toggleAlert = .presented(
            DoneTodoListModel<InMemoryStorage, MockGitHubIssueCreator>.ToggleAlertContext(
                item: item, itemWithState: itemWithState))
        #expect(model.toggleAlert.isPresented == true)

        model.toggleAlert = .dismissed
        #expect(model.toggleAlert.isPresented == false)
    }

    @Test("Create add edit model for editing")
    func createAddEditModelForEditing() async {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let service = GitHubService()
        let issueOperationService = GitHubIssueOperationService(service: service)
        let model = DoneTodoListModel(
            repository: repository, issueOperationService: issueOperationService)

        await model.repository.addWithoutIssue(title: "Test", detail: "Detail")
        await model.repository.toggleDone(model.repository.activeTodos.first!)
        let doneItem = model.repository.doneTodos.first!

        let addEditModel = model.createAddEditModel(editingItem: doneItem)

        #expect(addEditModel.editingItem?.id == doneItem.id)
        #expect(addEditModel.title == "Test")
        #expect(addEditModel.detail == "Detail")
        #expect(addEditModel.service != nil)
    }

    @Test("Pending toggle item can be set and cleared")
    func pendingToggleItemCanBeSetAndCleared() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        let item = TodoItem(title: "Test", detail: "")
        let itemWithState = TodoItemWithIssueState(item: item, issueState: .closed)
        model.toggleAlert = .presented(
            DoneTodoListModel<InMemoryStorage, MockGitHubIssueCreator>.ToggleAlertContext(
                item: item, itemWithState: itemWithState))

        #expect(model.toggleAlert.context?.item.id == item.id)

        model.toggleAlert = .dismissed
        #expect(model.toggleAlert.context == nil)
    }

    @Test("Delete all does not affect active todos")
    func deleteAllDoesNotAffectActiveTodos() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        // Add active todos
        await model.repository.addWithoutIssue(title: "Active 1", detail: "")
        await model.repository.addWithoutIssue(title: "Active 2", detail: "")

        // Add done todos
        await model.repository.addWithoutIssue(title: "Done 1", detail: "")
        await model.repository.toggleDone(model.repository.activeTodos.last!)

        await model.loadDoneTodos()  // Load into cache
        #expect(model.repository.activeTodos.count == 2)
        #expect(model.repository.doneTodos.count == 1)

        await model.deleteAllDoneTodos()

        #expect(model.repository.activeTodos.count == 2)
        #expect(model.repository.doneTodos.isEmpty)
    }

    @Test("Refresh clears in-memory state")
    func refreshClearsInMemoryState() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        await model.repository.addWithoutIssue(title: "Test", detail: "")
        let item = model.repository.activeTodos.first!
        await model.repository.toggleDone(item)

        let doneItem = model.repository.doneTodos.first!
        await model.handleToggle(doneItem)
        #expect(model.toggledItemIDs.contains(doneItem.id))

        await model.refresh()
        #expect(model.toggledItemIDs.isEmpty)
        #expect(model.displayedDoneTodos.isEmpty)
    }

    @Test("Effective done state reflects in-memory toggle")
    func effectiveDoneStateReflectsInMemoryToggle() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        await model.repository.addWithoutIssue(title: "Test", detail: "")
        let item = model.repository.activeTodos.first!
        await model.repository.toggleDone(item)
        await model.loadDoneTodos()

        let doneItem = model.repository.doneTodos.first!
        #expect(doneItem.isDone == true)

        await model.handleToggle(doneItem)
        let displayedItem = model.displayedDoneTodos.first!.item
        #expect(displayedItem.isDone == false)
    }

    @Test("Handle delete hides item from display")
    func handleDeleteHidesItemFromDisplay() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        await model.repository.addWithoutIssue(title: "Test", detail: "")
        let item = model.repository.activeTodos.first!
        await model.repository.toggleDone(item)

        await model.loadDoneTodos()
        let doneItem = model.displayedDoneTodos.first!.item
        await model.handleDelete(doneItem)

        #expect(model.repository.doneTodos.isEmpty)
        #expect(model.deletedItemIDs.contains(doneItem.id))
        #expect(model.displayedDoneTodos.isEmpty)
    }

    @Test("Unchecked item remains visible in done list with unchecked state")
    func uncheckedItemRemainsVisibleInDoneList() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        await model.repository.addWithoutIssue(title: "Test", detail: "")
        let item = model.repository.activeTodos.first!
        await model.repository.toggleDone(item)

        await model.loadDoneTodos()
        let doneItem = model.displayedDoneTodos.first!.item

        #expect(doneItem.isDone == true)
        #expect(doneItem.isDone == true)

        // Uncheck the item
        await model.handleToggle(doneItem)

        // Item should still be in displayed list
        #expect(model.displayedDoneTodos.count == 1)
        // Repository should be updated
        #expect(model.repository.activeTodos.count == 1)
        #expect(model.repository.doneTodos.isEmpty)
        // Get the displayed item (now from activeTodos)
        let displayedItem = model.displayedDoneTodos.first!.item
        // Effective state should show as not done
        #expect(displayedItem.isDone == false)
        // Item should be in toggled set
        #expect(model.toggledItemIDs.contains(doneItem.id))
    }

    @Test("Multiple toggles on done item work correctly")
    func multipleTogglesOnDoneItem() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        await model.repository.addWithoutIssue(title: "Test", detail: "")
        let item = model.repository.activeTodos.first!
        await model.repository.toggleDone(item)

        await model.loadDoneTodos()
        let doneItem = model.displayedDoneTodos.first!.item
        let itemId = doneItem.id

        // First toggle: done -> active
        await model.handleToggle(doneItem)
        #expect(model.displayedDoneTodos.count == 1)
        // Get the displayed item (which should still be showing)
        let displayedItem1 = model.displayedDoneTodos.first!.item
        #expect(displayedItem1.id == itemId)
        // Item is now in activeTodos (isDone=false), so effective state is false
        #expect(displayedItem1.isDone == false)
        #expect(model.repository.activeTodos.count == 1)

        // Second toggle: active -> done (toggle the displayed item)
        await model.handleToggle(displayedItem1)
        #expect(model.displayedDoneTodos.count == 1)
        let displayedItem2 = model.displayedDoneTodos.first!.item
        #expect(displayedItem2.id == itemId)
        // Item is now in doneTodos (isDone=true), so effective state is true
        #expect(displayedItem2.isDone == true)
        #expect(model.repository.doneTodos.count == 1)
    }

    @Test("Toggled items preserve their position in done list")
    func toggledItemsPreservePositionInDoneList() async throws {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        // Add items and mark them as done through repository
        await model.repository.addWithoutIssue(title: "First", detail: "")
        await model.repository.addWithoutIssue(title: "Second", detail: "")
        await model.repository.addWithoutIssue(title: "Third", detail: "")

        // Mark all as done
        for item in model.repository.activeTodos {
            await model.repository.toggleDone(item)
        }

        await model.loadDoneTodos()
        let items = model.displayedDoneTodos

        // Verify initial order (newest createdAt first)
        #expect(items.count == 3)
        #expect(items[0].item.title == "Third")
        #expect(items[1].item.title == "Second")
        #expect(items[2].item.title == "First")

        // Toggle the middle item (reopen it)
        let middleItem = items[1].item
        await model.handleToggle(middleItem)

        let displayedAfterToggle = model.displayedDoneTodos
        #expect(displayedAfterToggle.count == 3)

        // Order should be preserved: Third, Second (toggled), First
        #expect(displayedAfterToggle[0].item.title == "Third")
        #expect(displayedAfterToggle[1].item.title == "Second")
        #expect(displayedAfterToggle[2].item.title == "First")

        // Middle item should be marked as not done (check effective state)
        #expect(displayedAfterToggle[1].item.isDone == false)
    }

    @Test("Single done item unchecked remains visible")
    func singleDoneItemUncheckedRemainsVisible() async {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        let model = DoneTodoListModel(repository: repository)

        // Add one done item
        await model.repository.addWithoutIssue(title: "Test", detail: "")
        let item = model.repository.activeTodos.first!
        await model.repository.toggleDone(item)

        await model.loadDoneTodos()
        #expect(model.displayedDoneTodos.count == 1)

        let doneItem = model.displayedDoneTodos.first!.item

        // Uncheck it
        await model.handleToggle(doneItem)

        // Should still be displayed
        #expect(model.displayedDoneTodos.count == 1, "Item should remain visible after unchecking")
        #expect(model.toggledItemIDs.contains(doneItem.id), "Item should be in toggledItemIDs")

        let displayedItem = model.displayedDoneTodos.first!.item
        #expect(displayedItem.id == doneItem.id, "Same item should be displayed")
        #expect(displayedItem.isDone == false, "Item should show as not done (effective state)")
    }
}
