import Foundation

/// Manages alert display state
public enum AlertState<Context: Equatable>: Equatable {
    /// Alert dismissed
    case dismissed

    /// Alert presented (holds context information)
    case presented(Context)
}

extension AlertState {
    /// Whether alert is presented
    public var isPresented: Bool {
        if case .presented = self { return true }
        return false
    }

    /// Context information
    public var context: Context? {
        if case .presented(let context) = self { return context }
        return nil
    }
}

extension AlertState: Sendable where Context: Sendable {}
