import Logging

/// Service responsible for GitHub issue operations
@MainActor
final class GitHubIssueOperationService {
    let service: GitHubService

    init(service: GitHubService) {
        self.service = service
    }

    /// Updates the issue state by toggling between open and closed
    /// - Parameters:
    ///   - item: The todo item with associated GitHub issue
    ///   - stateReason: Optional reason for the state change
    /// - Throws: TodoError if the operation fails
    func toggleIssueState(for item: TodoItem, stateReason: IssueStateReason?) async throws {
        guard let issueNumber = item.gitHubIssueNumber else {
            return
        }

        // Fetch current issue state from GitHub API
        let currentIssue = try await service.issueCreator.getIssue(
            owner: service.repositorySettings.owner,
            repo: service.repositorySettings.repo,
            issueNumber: issueNumber
        )

        // Determine new state based on current GitHub state
        let newState = currentIssue.state == "open" ? "closed" : "open"

        _ = try await service.issueCreator.updateIssueState(
            owner: service.repositorySettings.owner,
            repo: service.repositorySettings.repo,
            issueNumber: issueNumber,
            state: newState,
            stateReason: stateReason
        )

        logger.debug(
            "Updated issue #\(issueNumber) from \(currentIssue.state) to \(newState) with reason: \(stateReason?.rawValue ?? "nil")"
        )
    }

    /// Closes the GitHub issue for a todo item
    /// - Parameters:
    ///   - item: The todo item with associated GitHub issue
    ///   - stateReason: Reason for closing the issue
    /// - Throws: TodoError if the operation fails
    func closeIssue(for item: TodoItem, stateReason: IssueStateReason) async throws {
        guard let issueNumber = item.gitHubIssueNumber else {
            return
        }

        _ = try await service.issueCreator.updateIssueState(
            owner: service.repositorySettings.owner,
            repo: service.repositorySettings.repo,
            issueNumber: issueNumber,
            state: "closed",
            stateReason: stateReason
        )

        logger.debug("Closed issue #\(issueNumber) as \(stateReason.rawValue)")
    }
}
