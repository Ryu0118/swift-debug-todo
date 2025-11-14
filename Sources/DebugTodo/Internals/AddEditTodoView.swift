import SwiftUI

@MainActor
@Observable
final class AddEditTodoModel<S: Storage, G: GitHubIssueCreatorProtocol> {
    let repository: TodoRepository<S, G>
    let repositorySettings: GitHubRepositorySettings?
    let service: GitHubService?
    let editingItem: TodoItem?

    var title: String
    var detail: String
    var showCreateIssueAlert = false
    var errorMessage: String?

    init(
        repository: TodoRepository<S, G>, repositorySettings: GitHubRepositorySettings? = nil,
        service: GitHubService? = nil, editingItem: TodoItem? = nil
    ) {
        self.repository = repository
        self.repositorySettings = repositorySettings
        self.service = service
        self.editingItem = editingItem
        self.title = editingItem?.title ?? ""
        self.detail = editingItem?.detail ?? ""
    }

    func save() async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }

        if let editingItem {
            // Update existing item
            var updatedItem = editingItem
            updatedItem.title = trimmedTitle
            updatedItem.detail = detail
            await repository.update(updatedItem)
            return true
        } else {
            // Add new item - check if confirmation is needed
            if let repositorySettings = repositorySettings, repositorySettings.showConfirmationAlert
            {
                showCreateIssueAlert = true
                return false
            } else {
                do {
                    try await repository.add(title: trimmedTitle, detail: detail, createIssue: true)
                    return true
                } catch {
                    errorMessage = error.localizedDescription
                    return false
                }
            }
        }
    }

    func updateGitHubIssue() async throws {
        guard let editingItem = editingItem,
            let service = service,
            let issueNumber = editingItem.gitHubIssueNumber
        else {
            return
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try await service.issueCreator.updateIssueContent(
            owner: service.repositorySettings.owner,
            repo: service.repositorySettings.repo,
            issueNumber: issueNumber,
            title: trimmedTitle,
            body: detail.isEmpty ? nil : detail
        )
        logger.debug("Updated issue #\(issueNumber) content")
    }

    func addWithIssue() async {
        // Validate GitHub settings
        guard let service = service else {
            errorMessage = "GitHub service is not configured"
            return
        }

        let settings = service.repositorySettings
        if settings.owner.isEmpty {
            errorMessage = "GitHub owner is not configured"
            return
        }
        if settings.repo.isEmpty {
            errorMessage = "GitHub repository is not configured"
            return
        }
        if service.credentials.personalAccessToken.isEmpty {
            errorMessage = "GitHub Personal Access Token is not configured"
            return
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await repository.add(title: trimmedTitle, detail: detail, createIssue: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addWithoutIssue() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        await repository.addWithoutIssue(title: trimmedTitle, detail: detail)
    }
}

struct AddEditTodoView<S: Storage, G: GitHubIssueCreatorProtocol>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @Bindable var model: AddEditTodoModel<S, G>

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("", text: $model.title, axis: .vertical)
                }
                Section("Detail") {
                    TextEditor(text: $model.detail)
                }
            }
            .navigationTitle(model.editingItem == nil ? "New" : "Edit")
            .toolbar {
                if model.editingItem == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        if #available(macOS 26.0, iOS 26.0, *) {
                            Button(role: .cancel) {
                                dismiss()
                            }
                        } else {
                            Button("Cancel", role: .cancel) {
                                dismiss()
                            }
                        }
                    }
                }

                if let editingItem = model.editingItem,
                    let issueUrl = editingItem.gitHubIssueUrl,
                    let url = URL(string: issueUrl)
                {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            openURL(url)
                        } label: {
                            Image(systemName: "link")
                        }
                    }

                    if #available(macOS 26.0, iOS 26.0, *) {
                        ToolbarSpacer()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(model.editingItem == nil ? "Add" : "Save") {
                        Task {
                            if await model.save() {
                                // Update GitHub issue if linked
                                do {
                                    try await model.updateGitHubIssue()
                                } catch {
                                    logger.error("Failed to update GitHub issue: \(error)")
                                }
                                dismiss()
                            }
                        }
                    }
                    .disabled(model.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Create GitHub Issue?", isPresented: $model.showCreateIssueAlert) {
                Button("Skip", role: .cancel) {
                    Task {
                        await model.addWithoutIssue()
                        dismiss()
                    }
                }
                Button("Create Issue", role: .destructive) {
                    Task {
                        await model.addWithIssue()
                        // Only dismiss if no error occurred
                        if model.errorMessage == nil {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Do you want to create a GitHub issue for this todo?")
            }
            .alert(
                "Failed to Create Issue",
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
        }
    }
}
