import Foundation

/// アラート表示の状態を管理
public enum AlertState<Context: Equatable>: Equatable {
    /// アラート非表示
    case dismissed

    /// アラート表示中（コンテキスト情報を保持）
    case presented(Context)
}

extension AlertState {
    /// アラートが表示されているかどうか
    public var isPresented: Bool {
        if case .presented = self { return true }
        return false
    }

    /// コンテキスト情報
    public var context: Context? {
        if case .presented(let context) = self { return context }
        return nil
    }
}

extension AlertState: Sendable where Context: Sendable {}
