import Foundation

/// GitHub Issue操作の状態を管理
public enum IssueOperationState<ErrorType: Error> {
    /// 操作が行われていない
    case idle

    /// 操作中
    case inProgress

    /// 操作成功
    case succeeded

    /// 操作失敗
    case failed(ErrorType)
}

extension IssueOperationState {
    /// 操作中かどうか
    public var isInProgress: Bool {
        if case .inProgress = self { return true }
        return false
    }

    /// エラー情報
    public var error: ErrorType? {
        if case .failed(let error) = self { return error }
        return nil
    }

    /// 成功したかどうか
    public var isSucceeded: Bool {
        if case .succeeded = self { return true }
        return false
    }
}

extension IssueOperationState: Equatable where ErrorType: Equatable {}
extension IssueOperationState: Sendable where ErrorType: Sendable {}
