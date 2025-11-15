import Foundation

/// Errors related to Todo operations
public enum TodoError: Error, Equatable, Sendable {
    /// Storage operation error
    case storageError(String)

    /// GitHub API related error
    case githubError(GitHubError)

    /// Validation error
    case validationError(String)

    /// Other errors
    case unknown(String)
}

/// Errors related to GitHub operations
public enum GitHubError: Error, Equatable, Sendable {
    /// Issue creation failed
    case issueCreationFailed(String)

    /// Issue update failed
    case issueUpdateFailed(String)

    /// Issue fetch failed
    case issueFetchFailed(String)

    /// Authentication error
    case authenticationError(String)

    /// Network error
    case networkError(String)

    /// Incomplete settings
    case incompleteSettings(String)
}

extension TodoError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .storageError(let message):
            return "Storage error: \(message)"
        case .githubError(let error):
            return "GitHub error: \(error.localizedDescription)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

extension GitHubError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .issueCreationFailed(let message):
            return "Failed to create issue: \(message)"
        case .issueUpdateFailed(let message):
            return "Failed to update issue: \(message)"
        case .issueFetchFailed(let message):
            return "Failed to fetch issue: \(message)"
        case .authenticationError(let message):
            return "Authentication error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .incompleteSettings(let message):
            return "Incomplete settings: \(message)"
        }
    }
}
