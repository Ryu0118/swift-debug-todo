import Logging
import SwiftUI

@MainActor
@Observable
public final class GitHubSettingsModel {
    let service: GitHubService
    var saveOperationState: IssueOperationState<TodoError> = .idle
    var showSuccessAlert = false

    // Local editing state (not persisted until saved)
    var editingToken: String = ""
    var editingOwner: String = ""
    var editingRepo: String = ""
    var editingShowConfirmationAlert: Bool = true

    private var hasLoadedInitialSettings = false

    public init(service: GitHubService) {
        self.service = service
    }

    func loadCurrentSettings() {
        // Only load if we haven't loaded yet, to avoid clearing user input
        guard !hasLoadedInitialSettings else { return }

        editingToken = service.credentials.accessToken ?? ""
        editingOwner = service.repositorySettings.owner
        editingRepo = service.repositorySettings.repo
        editingShowConfirmationAlert = service.repositorySettings.showConfirmationAlert
        hasLoadedInitialSettings = true
    }

    func resetToSavedSettings() {
        editingToken = service.credentials.accessToken ?? ""
        editingOwner = service.repositorySettings.owner
        editingRepo = service.repositorySettings.repo
        editingShowConfirmationAlert = service.repositorySettings.showConfirmationAlert
    }

    var isValid: Bool {
        !editingOwner.isEmpty && !editingRepo.isEmpty
    }

    func saveConfiguration() async {
        saveOperationState = .inProgress

        do {
            // Update service with edited values
            service.repositorySettings.owner = editingOwner
            service.repositorySettings.repo = editingRepo
            service.repositorySettings.showConfirmationAlert = editingShowConfirmationAlert

            try await service.saveRepositorySettings()
            try await service.credentials.saveToken(editingToken)

            saveOperationState = .succeeded
            showSuccessAlert = true
        } catch {
            let todoError = TodoError.storageError(error.localizedDescription)
            saveOperationState = .failed(todoError)
        }
    }

    func clearToken() async {
        await service.credentials.signOut()
        resetToSavedSettings()
    }
}

/// A view for configuring GitHub integration settings.
public struct GitHubSettingsView: View {
    @Bindable var model: GitHubSettingsModel

    public init(model: GitHubSettingsModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            Section {
                SecureField("Personal Access Token", text: $model.editingToken)
                    .autocorrectionDisabled()
                    #if os(iOS) || os(visionOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                    #endif

                if model.service.credentials.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Token Saved")
                        Spacer()
                        Button("Clear", role: .destructive) {
                            Task {
                                await model.clearToken()
                            }
                        }
                    }
                }
            } header: {
                Text("Authentication")
            } footer: {
                Text(
                    "Generate a Personal Access Token with 'repo' scope from GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)."
                )
            }

            Section {
                TextField("Owner", text: $model.editingOwner)
                    .autocorrectionDisabled()
                    #if os(iOS) || os(visionOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                    #endif

                TextField("Repository", text: $model.editingRepo)
                    .autocorrectionDisabled()
                    #if os(iOS) || os(visionOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                    #endif

                if model.isValid {
                    HStack {
                        Text("Full name:")
                        Spacer()
                        Text("\(model.editingOwner)/\(model.editingRepo)")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Repository")
            } footer: {
                Text("Enter the owner and repository name where issues will be created.")
            }

            Section {
                Toggle(
                    "Confirm Before Creating Issue",
                    isOn: $model.editingShowConfirmationAlert
                )
            } header: {
                Text("Options")
            } footer: {
                Text("Show alert before creating a GitHub issue.")
            }
        }
        .navigationTitle("GitHub Settings")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    Task {
                        await model.saveConfiguration()
                    }
                }
                .disabled(!model.isValid || model.saveOperationState.isInProgress)
            }
        }
        .onAppear {
            model.loadCurrentSettings()
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { model.saveOperationState.error != nil },
                set: { if !$0 { model.saveOperationState = .idle } }
            )
        ) {
            Button("OK", role: .cancel) {
                model.saveOperationState = .idle
            }
        } message: {
            if let error = model.saveOperationState.error {
                Text(error.localizedDescription)
            }
        }
        .alert("Saved", isPresented: $model.showSuccessAlert) {
            Button("OK", role: .cancel) {
                model.saveOperationState = .idle
            }
        } message: {
            Text("GitHub settings saved successfully")
        }
    }
}
