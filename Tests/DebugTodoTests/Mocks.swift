import Foundation
@testable import DebugTodo

@MainActor
final class MockGitHubIssueCreator: GitHubIssueCreatorProtocol {
    var onTodoCreatedResult: Result<GitHubIssue?, Error> = .success(nil)
    var createIssueResult: Result<GitHubIssue?, Error> = .success(nil)

    var onTodoCreatedCalls: [TodoItem] = []
    var createIssueCalls: [TodoItem] = []

    func onTodoCreated(_ item: TodoItem) async throws -> GitHubIssue? {
        onTodoCreatedCalls.append(item)
        switch onTodoCreatedResult {
        case .success(let issue):
            return issue
        case .failure(let error):
            throw error
        }
    }

    func createIssue(for item: TodoItem) async throws -> GitHubIssue? {
        createIssueCalls.append(item)
        switch createIssueResult {
        case .success(let issue):
            return issue
        case .failure(let error):
            throw error
        }
    }

    enum MockError: Error {
        case notImplemented
    }
}

@MainActor
final class MockGitHubService {
    var repositorySettings: GitHubRepositorySettings
    let issueCreator: MockGitHubIssueCreator

    init(repositorySettings: GitHubRepositorySettings = GitHubRepositorySettings(owner: "test", repo: "test-repo", showConfirmationAlert: false)) {
        self.repositorySettings = repositorySettings
        self.issueCreator = MockGitHubIssueCreator()
    }
}
