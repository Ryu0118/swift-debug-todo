import Foundation

/// Manages GitHub Issue operation state
public enum IssueOperationState<ErrorType: Error> {
    /// No operation in progress
    case idle

    /// Operation in progress
    case inProgress

    /// Operation succeeded
    case succeeded

    /// Operation failed
    case failed(ErrorType)
}

extension IssueOperationState {
    /// Whether operation is in progress
    public var isInProgress: Bool {
        if case .inProgress = self { return true }
        return false
    }

    /// Error information
    public var error: ErrorType? {
        if case .failed(let error) = self { return error }
        return nil
    }

    /// Whether operation succeeded
    public var isSucceeded: Bool {
        if case .succeeded = self { return true }
        return false
    }
}

extension IssueOperationState: Equatable where ErrorType: Equatable {}
extension IssueOperationState: Sendable where ErrorType: Sendable {}
