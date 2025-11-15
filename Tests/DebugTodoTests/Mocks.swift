import Foundation

@testable import DebugTodo

@MainActor
final class MockGitHubIssueCreator: GitHubIssueCreatorProtocol {
    var onTodoCreatedResult: Result<GitHubIssue?, Error> = .success(nil)
    var createIssueResult: Result<GitHubIssue?, Error> = .success(nil)
    var getIssueResult: Result<GitHubIssue, Error> = .success(
        GitHubIssue(
            id: 1,
            number: 1,
            title: "Test Issue",
            body: nil,
            htmlUrl: "https://github.com/test/repo/issues/1",
            state: "open"
        )
    )
    var updateIssueStateResult: Result<GitHubIssue, Error> = .success(
        GitHubIssue(
            id: 1,
            number: 1,
            title: "Test Issue",
            body: nil,
            htmlUrl: "https://github.com/test/repo/issues/1",
            state: "closed"
        )
    )
    var updateIssueContentResult: Result<GitHubIssue, Error> = .success(
        GitHubIssue(
            id: 1,
            number: 1,
            title: "Updated Title",
            body: "Updated Body",
            htmlUrl: "https://github.com/test/repo/issues/1",
            state: "open"
        )
    )

    var onTodoCreatedCalls: [TodoItem] = []
    var createIssueCalls: [TodoItem] = []
    var getIssueCalls: [(owner: String, repo: String, issueNumber: Int)] = []
    var updateIssueStateCalls:
        [(
            owner: String, repo: String, issueNumber: Int, state: String,
            stateReason: IssueStateReason?
        )] = []
    var updateIssueContentCalls:
        [(owner: String, repo: String, issueNumber: Int, title: String, body: String?)] = []

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

    func getIssue(owner: String, repo: String, issueNumber: Int) async throws -> GitHubIssue {
        getIssueCalls.append((owner, repo, issueNumber))
        switch getIssueResult {
        case .success(let issue):
            return issue
        case .failure(let error):
            throw error
        }
    }

    func updateIssueState(
        owner: String,
        repo: String,
        issueNumber: Int,
        state: String,
        stateReason: IssueStateReason?
    ) async throws -> GitHubIssue {
        updateIssueStateCalls.append((owner, repo, issueNumber, state, stateReason))
        switch updateIssueStateResult {
        case .success(let issue):
            return issue
        case .failure(let error):
            throw error
        }
    }

    func updateIssueContent(
        owner: String,
        repo: String,
        issueNumber: Int,
        title: String,
        body: String?
    ) async throws -> GitHubIssue {
        updateIssueContentCalls.append((owner, repo, issueNumber, title, body))
        switch updateIssueContentResult {
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

    init(
        repositorySettings: GitHubRepositorySettings = GitHubRepositorySettings(
            owner: "test", repo: "test-repo", showConfirmationAlert: false)
    ) {
        self.repositorySettings = repositorySettings
        self.issueCreator = MockGitHubIssueCreator()
    }
}
