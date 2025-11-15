import Foundation

/// 非同期データの状態を表現する汎用的なenum
///
/// - Case 0: 基本的なloading/loaded/error状態
/// - Case 1: 再読み込み中もデータを保持
/// - Case 4: 再読み込み失敗時も前のデータを保持
public enum DataState<Value, ErrorType: Error> {
    /// データが読み込まれていない、または初期状態
    case idle

    /// データを読み込み中（オプショナルで過去のデータを保持）
    case loading(Value?)

    /// データの読み込みに成功
    case loaded(Value)

    /// データの読み込みに失敗（オプショナルで過去のデータを保持）
    case failed(ErrorType, Value?)
}

extension DataState {
    /// 現在保持しているデータ（あればnil、なければnil）
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

    /// エラー情報（エラー状態でなければnil）
    public var error: ErrorType? {
        switch self {
        case .failed(let error, _):
            return error
        default:
            return nil
        }
    }

    /// ローディング中かどうか
    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    /// データが存在するかどうか
    public var hasValue: Bool {
        value != nil
    }

    /// データをマップして新しいDataStateを作成
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
