import Foundation

/// Todo操作に関するエラー
public enum TodoError: Error, Equatable, Sendable {
    /// ストレージ操作のエラー
    case storageError(String)

    /// GitHub API関連のエラー
    case githubError(GitHubError)

    /// バリデーションエラー
    case validationError(String)

    /// その他のエラー
    case unknown(String)
}

/// GitHub操作に関するエラー
public enum GitHubError: Error, Equatable, Sendable {
    /// Issue作成失敗
    case issueCreationFailed(String)

    /// Issue更新失敗
    case issueUpdateFailed(String)

    /// Issue取得失敗
    case issueFetchFailed(String)

    /// 認証エラー
    case authenticationError(String)

    /// ネットワークエラー
    case networkError(String)

    /// 設定が不完全
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
