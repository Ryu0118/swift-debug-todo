import Foundation

/// Represents the state of a GitHub issue.
public enum GitHubIssueState: String, Codable, Sendable {
    case open
    case closed

    /// Returns the display text for the issue state.
    public var displayText: String {
        rawValue
    }
}
