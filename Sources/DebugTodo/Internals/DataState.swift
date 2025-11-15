import Foundation

/// Generic enum representing the state of asynchronous data
///
/// - Case 0: Basic loading/loaded/error states
/// - Case 1: Retains data while reloading
/// - Case 4: Retains previous data on reload failure
public enum DataState<Value, ErrorType: Error> {
    /// Data not loaded or in initial state
    case idle

    /// Loading data (optionally retains previous data)
    case loading(Value?)

    /// Successfully loaded data
    case loaded(Value)

    /// Failed to load data (optionally retains previous data)
    case failed(ErrorType, Value?)
}

extension DataState {
    /// Currently held data (nil if none)
    public var value: Value? {
        switch self {
        case .idle:
            return nil
        case .loading(let previous):
            return previous
        case .loaded(let value):
            return value
        case .failed(_, let previous):
            return previous
        }
    }

    /// Error information (nil if not in error state)
    public var error: ErrorType? {
        switch self {
        case .failed(let error, _):
            return error
        default:
            return nil
        }
    }

    /// Whether currently loading
    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    /// Whether data exists
    public var hasValue: Bool {
        value != nil
    }

    /// Map data to create a new DataState
    public func map<T>(_ transform: (Value) -> T) -> DataState<T, ErrorType> {
        switch self {
        case .idle:
            return .idle
        case .loading(let previous):
            return .loading(previous.map(transform))
        case .loaded(let value):
            return .loaded(transform(value))
        case .failed(let error, let previous):
            return .failed(error, previous.map(transform))
        }
    }
}

extension DataState: Equatable where Value: Equatable, ErrorType: Equatable {}
extension DataState: Sendable where Value: Sendable, ErrorType: Sendable {}
