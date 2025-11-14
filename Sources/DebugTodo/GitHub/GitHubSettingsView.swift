import Logging
import SwiftUI

@MainActor
@Observable
public final class GitHubSettingsModel {
    var service: GitHubService
    var errorMessage: String?
    var showSuccess = false

    public init(service: GitHubService) {
        self.service = service
    }

    func saveConfiguration() async {
        do {
            try await service.saveRepositorySettings()
            try await service.credentials.saveToken()
            showSuccess = true
        } catch {
            errorMessage = "Failed to save configuration: \(error.localizedDescription)"
        }
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
                SecureField(
                    "Personal Access Token", text: $model.service.credentials.personalAccessToken
                )
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
                            model.service.credentials.signOut()
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
                TextField("Owner", text: $model.service.repositorySettings.owner)
                    .autocorrectionDisabled()
                    #if os(iOS) || os(visionOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                    #endif

                TextField("Repository", text: $model.service.repositorySettings.repo)
                    .autocorrectionDisabled()
                    #if os(iOS) || os(visionOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                    #endif

                if model.service.repositorySettings.isValid {
                    HStack {
                        Text("Full name:")
                        Spacer()
                        Text(model.service.repositorySettings.fullName)
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
                    isOn: $model.service.repositorySettings.showConfirmationAlert)
            } header: {
                Text("Options")
            } footer: {
                Text("Show alert before creating a GitHub issue.")
            }

            Section {
                Button("Save") {
                    Task {
                        await model.saveConfiguration()
                    }
                }
                .disabled(!model.service.repositorySettings.isValid)
            }
        }
        .navigationTitle("GitHub Settings")
        .alert(
            "Error",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
            }
        }
        .alert("Saved", isPresented: $model.showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("GitHub settings saved successfully")
        }
    }
}
