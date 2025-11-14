import Foundation
import Testing

@testable import DebugTodo

@Suite("GitHubSettingsModel Tests")
@MainActor
struct GitHubSettingsModelTests {

    @Test("Initialize model with service")
    func initialize() {
        let service = GitHubService()
        let model = GitHubSettingsModel(service: service)

        #expect(model.errorMessage == nil)
        #expect(model.showSuccess == false)
    }

    @Test("Save configuration sets success flag")
    func saveConfigurationSetsSuccessFlag() {
        let tokenStorage = InMemoryTokenStorage()
        try? tokenStorage.saveToken("test-token")

        let service = GitHubService(
            tokenStorage: tokenStorage,
            repositorySettingsStorage: InMemoryRepositorySettingsStorage()
        )
        service.repositorySettings = GitHubRepositorySettings(
            owner: "test", repo: "repo", showConfirmationAlert: false)
        service.credentials.personalAccessToken = "test-token"

        let model = GitHubSettingsModel(service: service)

        model.saveConfiguration()

        #expect(model.showSuccess == true)
        #expect(model.errorMessage == nil)
    }

    @Test("Save configuration sets error message on failure")
    func saveConfigurationSetsErrorOnFailure() {
        let service = GitHubService(
            tokenStorage: InMemoryTokenStorage(),
            repositorySettingsStorage: FailingRepositorySettingsStorage()
        )

        let model = GitHubSettingsModel(service: service)

        model.saveConfiguration()

        #expect(model.errorMessage != nil)
        #expect(model.showSuccess == false)
    }

    @Test("Model holds reference to service")
    func modelHoldsReferenceToService() {
        let service = GitHubService()
        service.repositorySettings = GitHubRepositorySettings(
            owner: "test-owner", repo: "test-repo", showConfirmationAlert: true)

        let model = GitHubSettingsModel(service: service)

        #expect(model.service.repositorySettings.owner == "test-owner")
        #expect(model.service.repositorySettings.repo == "test-repo")
        #expect(model.service.repositorySettings.showConfirmationAlert == true)
    }

    @Test("Error message can be cleared")
    func errorMessageCanBeCleared() {
        let service = GitHubService(
            tokenStorage: InMemoryTokenStorage(),
            repositorySettingsStorage: FailingRepositorySettingsStorage()
        )

        let model = GitHubSettingsModel(service: service)

        model.saveConfiguration()
        #expect(model.errorMessage != nil)

        model.errorMessage = nil
        #expect(model.errorMessage == nil)
    }

    @Test("Success flag can be reset")
    func successFlagCanBeReset() {
        let tokenStorage = InMemoryTokenStorage()
        try? tokenStorage.saveToken("test-token")

        let service = GitHubService(
            tokenStorage: tokenStorage,
            repositorySettingsStorage: InMemoryRepositorySettingsStorage()
        )
        service.repositorySettings = GitHubRepositorySettings(
            owner: "test", repo: "repo", showConfirmationAlert: false)
        service.credentials.personalAccessToken = "test-token"

        let model = GitHubSettingsModel(service: service)

        model.saveConfiguration()
        #expect(model.showSuccess == true)

        model.showSuccess = false
        #expect(model.showSuccess == false)
    }
}

// MARK: - Mock Storage Implementations

final class InMemoryTokenStorage: @unchecked Sendable, GitHubTokenStorage {
    private let lock = NSLock()
    private var _token: String?

    func saveToken(_ token: String) async throws {
        lock.lock()
        defer { lock.unlock() }
        _token = token
    }

    func loadToken() async throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return _token
    }

    func deleteToken() async throws {
        lock.lock()
        defer { lock.unlock() }
        _token = nil
    }

    nonisolated init() {}
}

final class InMemoryRepositorySettingsStorage: @unchecked Sendable, GitHubRepositorySettingsStorage
{
    private let lock = NSLock()
    private var _settings: GitHubRepositorySettings?

    func save(_ settings: GitHubRepositorySettings) async throws {
        lock.lock()
        defer { lock.unlock() }
        _settings = settings
    }

    func load() async throws -> GitHubRepositorySettings {
        lock.lock()
        defer { lock.unlock() }
        guard let settings = _settings else {
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
