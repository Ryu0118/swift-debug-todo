import Foundation
import os

@testable import DebugTodo

// MARK: - Test Storage Implementations

final class TestTokenStorage: @unchecked Sendable, GitHubTokenStorage {
    private let token = OSAllocatedUnfairLock<String?>(initialState: nil)

    func saveToken(_ token: String) async throws {
        self.token.withLock { $0 = token }
    }

    func loadToken() async throws -> String? {
        token.withLock { $0 }
    }

    func deleteToken() async throws {
        token.withLock { $0 = nil }
    }

    nonisolated init() {}
}

final class TestRepositorySettingsStorage: @unchecked Sendable, GitHubRepositorySettingsStorage {
    private let settings = OSAllocatedUnfairLock<GitHubRepositorySettings?>(initialState: nil)

    func save(_ settings: GitHubRepositorySettings) async throws {
        self.settings.withLock { $0 = settings }
    }

    func load() async throws -> GitHubRepositorySettings {
        guard let settings = settings.withLock({ $0 }) else {
            throw StorageError.notFound
        }
        return settings
    }

    nonisolated init() {}

    enum StorageError: Error {
        case notFound
    }
}

final class FailingRepositorySettingsStorage: GitHubRepositorySettingsStorage {
    func save(_ settings: GitHubRepositorySettings) async throws {
        throw SaveError.failed
    }

    func load() async throws -> GitHubRepositorySettings {
        throw LoadError.failed
    }

    nonisolated init() {}

    enum SaveError: Error {
        case failed
    }

    enum LoadError: Error {
        case failed
    }
}
