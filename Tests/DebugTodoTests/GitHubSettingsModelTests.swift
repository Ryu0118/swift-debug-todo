import Foundation
import Testing
import os

@testable import DebugTodo

@Suite("GitHubSettingsModel Tests")
@MainActor
struct GitHubSettingsModelTests {

    @Test("Initialize model with service")
    func initialize() {
        let service = GitHubService()
        let model = GitHubSettingsModel(service: service)

        #expect(model.saveOperationState.error == nil)
        #expect(model.showSuccessAlert == false)
    }

    @Test("Save configuration sets success flag")
    func saveConfigurationSetsSuccessFlag() async throws {
        let tokenStorage = TestTokenStorage()
        try await tokenStorage.saveToken("test-token")

        let service = GitHubService(
            tokenStorage: tokenStorage,
            repositorySettingsStorage: TestRepositorySettingsStorage()
        )

        let model = GitHubSettingsModel(service: service)
        model.editingOwner = "test"
        model.editingRepo = "repo"
        model.editingShowConfirmationAlert = false
        model.editingToken = "test-token"

        await model.saveConfiguration()

        #expect(model.saveOperationState.isSucceeded)
        #expect(model.showSuccessAlert == true)
        #expect(model.saveOperationState.error == nil)
    }

    @Test("Save configuration sets error message on failure")
    func saveConfigurationSetsErrorOnFailure() async {
        let service = GitHubService(
            tokenStorage: TestTokenStorage(),
            repositorySettingsStorage: FailingRepositorySettingsStorage()
        )

        let model = GitHubSettingsModel(service: service)

        await model.saveConfiguration()

        #expect(model.saveOperationState.error != nil)
        #expect(!model.saveOperationState.isSucceeded)
        #expect(model.showSuccessAlert == false)
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
    func errorMessageCanBeCleared() async {
        let service = GitHubService(
            tokenStorage: TestTokenStorage(),
            repositorySettingsStorage: FailingRepositorySettingsStorage()
        )

        let model = GitHubSettingsModel(service: service)

        await model.saveConfiguration()
        #expect(model.saveOperationState.error != nil)

        model.saveOperationState = .idle
        #expect(model.saveOperationState.error == nil)
    }

    @Test("Success flag can be reset")
    func successFlagCanBeReset() async throws {
        let tokenStorage = TestTokenStorage()
        try await tokenStorage.saveToken("test-token")

        let service = GitHubService(
            tokenStorage: tokenStorage,
            repositorySettingsStorage: TestRepositorySettingsStorage()
        )

        let model = GitHubSettingsModel(service: service)
        model.editingOwner = "test"
        model.editingRepo = "repo"
        model.editingShowConfirmationAlert = false
        model.editingToken = "test-token"

        await model.saveConfiguration()
        #expect(model.showSuccessAlert == true)

        model.showSuccessAlert = false
        #expect(model.showSuccessAlert == false)
    }
}

// Note: Test storage implementations are in TestHelpers.swift
