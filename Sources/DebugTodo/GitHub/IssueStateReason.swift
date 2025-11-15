import Foundation

/// Represents the reason for closing a GitHub issue.
///
/// GitHub API supports the following state reasons when closing an issue:
/// - `completed`: The issue was completed successfully
/// - `notPlanned`: The issue is not planned to be worked on
/// - `duplicate`: The issue is a duplicate of another issue
/// - `reopened`: Used when reopening a closed issue (represented as `nil` in the API)
public enum IssueStateReason: String, Sendable {
    case completed
    case notPlanned = "not_planned"
    case duplicate
    case reopened

    /// Converts the enum to the string value expected by the GitHub API.
    /// - Returns: The string representation for the API, or `nil` for reopened issues.
    var apiValue: String? {
        switch self {
        case .completed:
            return "completed"
        case .notPlanned:
            return "not_planned"
        case .duplicate:
            return "duplicate"
        case .reopened:
            return nil
        }
    }
}
