import Foundation
import Testing
import os

@testable import DebugTodo

@Suite("AddEditTodoModel Tests")
@MainActor
struct AddEditTodoModelTests {

    @Test("Initialize model for adding new todo")
    func initializeForAddingNew() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let model = AddEditTodoModel(repository: repository)

        #expect(model.editingItem == nil)
        #expect(model.title.isEmpty)
        #expect(model.detail.isEmpty)
        #expect(!model.createIssueAlert.isPresented)
        #expect(model.issueCreationState.error == nil)
    }

    @Test("Initialize model for editing existing todo")
    func initializeForEditing() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let item = TodoItem(title: "Test Title", detail: "Test Detail")
        let model = AddEditTodoModel(repository: repository, editingItem: item)

        #expect(model.editingItem?.id == item.id)
        #expect(model.title == "Test Title")
        #expect(model.detail == "Test Detail")
    }

    @Test("Save returns false when title is empty")
    func saveReturnsFalseWhenTitleIsEmpty() async {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let model = AddEditTodoModel(repository: repository)

        model.title = ""
        let result = await model.save()

        #expect(result == false)
        #expect(repository.activeTodos.isEmpty)
    }

    @Test("Save returns false when title is whitespace only")
    func saveReturnsFalseWhenTitleIsWhitespace() async {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let model = AddEditTodoModel(repository: repository)

        model.title = "   \n\t  "
        let result = await model.save()

        #expect(result == false)
        #expect(repository.activeTodos.isEmpty)
    }

    @Test("Save adds new todo without confirmation when no repository settings")
    func saveAddsNewTodoWithoutConfirmation() async {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let model = AddEditTodoModel(repository: repository)

        model.title = "New Todo"
        model.detail = "Details"
        let result = await model.save()

        #expect(result == true)
        #expect(repository.activeTodos.count == 1)
        #expect(repository.activeTodos.first?.title == "New Todo")
        #expect(repository.activeTodos.first?.detail == "Details")
    }

    @Test("Save adds new todo without confirmation when confirmation disabled")
    func saveAddsNewTodoWhenConfirmationDisabled() async {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let settings = GitHubRepositorySettings(
            owner: "test", repo: "repo", showConfirmationAlert: false)
        let model = AddEditTodoModel(repository: repository, repositorySettings: settings)

        model.title = "New Todo"
        let result = await model.save()

        #expect(result == true)
        #expect(repository.activeTodos.count == 1)
    }

    @Test("Save shows confirmation alert when confirmation enabled")
    func saveShowsConfirmationAlertWhenEnabled() async {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let settings = GitHubRepositorySettings(
            owner: "test", repo: "repo", showConfirmationAlert: true)
        let model = AddEditTodoModel(repository: repository, repositorySettings: settings)

        model.title = "New Todo"
        let result = await model.save()

        #expect(result == false)
        #expect(model.createIssueAlert.isPresented)
        #expect(repository.activeTodos.isEmpty)
    }

    @Test("Save updates existing todo")
    func saveUpdatesExistingTodo() async throws {
        let storage = InMemoryStorage()
        let repository = TodoRepository(storage: storage, issueCreator: MockGitHubIssueCreator())
        try await repository.add(title: "Original", detail: "Original Detail", createIssue: false)
        let item = repository.activeTodos.first!

        let model = AddEditTodoModel(repository: repository, editingItem: item)
        model.title = "Updated"
        model.detail = "Updated Detail"
        let result = await model.save()

        #expect(result == true)
        #expect(repository.activeTodos.count == 1)
        #expect(repository.activeTodos.first?.title == "Updated")
        #expect(repository.activeTodos.first?.detail == "Updated Detail")
    }

    @Test("Save trims whitespace from title")
    func saveTrimWhitespaceFromTitle() async {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let model = AddEditTodoModel(repository: repository)

        model.title = "  Trimmed Title  "
        let result = await model.save()

        #expect(result == true)
        #expect(repository.activeTodos.first?.title == "Trimmed Title")
    }

    @Test("Add with issue creates todo when service is configured")
    func addWithIssue() async throws {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())

        // Use test storages that don't have async initialization issues
        let tokenStorage = TestTokenStorage()
        let settingsStorage = TestRepositorySettingsStorage()

        let service = GitHubService(
            tokenStorage: tokenStorage,
            repositorySettingsStorage: settingsStorage
        )

        // Configure settings
        service.repositorySettings.owner = "test"
        service.repositorySettings.repo = "repo"
        try await service.credentials.saveToken("test-token")

        let model = AddEditTodoModel(repository: repository, service: service)

        model.title = "New Todo"
        model.detail = "Details"
        await model.addWithIssue()

        #expect(repository.activeTodos.count == 1)
        #expect(repository.activeTodos.first?.title == "New Todo")
        #expect(model.issueCreationState.isSucceeded || model.issueCreationState.error == nil)
    }

    @Test("Add without issue creates todo")
    func addWithoutIssue() async {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let model = AddEditTodoModel(repository: repository)

        model.title = "New Todo"
        model.detail = "Details"
        await model.addWithoutIssue()

        #expect(repository.activeTodos.count == 1)
        #expect(repository.activeTodos.first?.title == "New Todo")
    }

    @Test("Issue creation state can be set to failed")
    func issueCreationStateCanBeSetToFailed() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let model = AddEditTodoModel(repository: repository)

        model.issueCreationState = .failed(.validationError("Test error"))

        #expect(model.issueCreationState.error != nil)
    }

    @Test("Issue creation state can be cleared")
    func issueCreationStateCanBeCleared() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let model = AddEditTodoModel(repository: repository)

        model.issueCreationState = .failed(.validationError("Test error"))
        model.issueCreationState = .idle

        #expect(model.issueCreationState.error == nil)
    }

    @Test("Create issue alert flag can be toggled")
    func createIssueAlertCanBeToggled() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let model = AddEditTodoModel(repository: repository)

        model.createIssueAlert = .presented(AddEditTodoModel<InMemoryStorage, MockGitHubIssueCreator>.CreateIssueAlertContext())
        #expect(model.createIssueAlert.isPresented)

        model.createIssueAlert = .dismissed
        #expect(!model.createIssueAlert.isPresented)
    }

    @Test("Model preserves repository settings")
    func modelPreservesRepositorySettings() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let settings = GitHubRepositorySettings(
            owner: "test-owner", repo: "test-repo", showConfirmationAlert: true)
        let model = AddEditTodoModel(repository: repository, repositorySettings: settings)

        #expect(model.repositorySettings?.owner == "test-owner")
        #expect(model.repositorySettings?.repo == "test-repo")
        #expect(model.repositorySettings?.showConfirmationAlert == true)
    }

    @Test("Model preserves service reference")
    func modelPreservesServiceReference() {
        let repository = TodoRepository(
            storage: InMemoryStorage(), issueCreator: MockGitHubIssueCreator())
        let service = GitHubService()
        let model = AddEditTodoModel(repository: repository, service: service)

        #expect(model.service != nil)
    }
}
