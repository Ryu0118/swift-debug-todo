import SwiftUI

#if canImport(UIKit)
    import FullscreenPopup
#endif

@MainActor
@Observable
final class AddEditTodoModel<S: Storage, G: GitHubIssueCreatorProtocol> {
    struct CreateIssueAlertContext: Equatable {}

    let repository: TodoRepository<S, G>
    let repositorySettings: GitHubRepositorySettings?
    let service: GitHubService?
    let editingItem: TodoItem?

    var title: String
    var detail: String
    var createIssueAlert: AlertState<CreateIssueAlertContext> = .dismissed
    var issueCreationState: IssueOperationState<TodoError> = .idle

    init(
        repository: TodoRepository<S, G>,
        repositorySettings: GitHubRepositorySettings? = nil,
        service: GitHubService? = nil,
        editingItem: TodoItem? = nil
    ) {
        self.repository = repository
        self.repositorySettings = repositorySettings
        self.service = service
        self.editingItem = editingItem
        self.title = editingItem?.title ?? ""
        self.detail = editingItem?.detail ?? ""
    }

    /// Saves the todo item (either updating an existing item or adding a new one).
    ///
    /// - Returns: `true` if the item was saved successfully, `false` if:
    ///   - The title is empty or whitespace-only
    ///   - A confirmation alert needs to be shown (new item with `showConfirmationAlert` enabled)
    ///   - An error occurred while creating a GitHub issue
    func save() async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }

        if let editingItem {
            return await updateExistingItem(editingItem, trimmedTitle: trimmedTitle)
        } else {
            return await addNewItemIfNeeded()
        }
    }

    private func updateExistingItem(_ item: TodoItem, trimmedTitle: String) async -> Bool {
        var updatedItem = item
        updatedItem.title = trimmedTitle
        updatedItem.detail = detail
        await repository.update(updatedItem)

        // Update GitHub issue if linked
        if item.gitHubIssueUrl != nil {
            issueCreationState = .inProgress

            do {
                try await updateGitHubIssue()
                issueCreationState = .succeeded
            } catch {
                let todoError = mapError(error)
                issueCreationState = .failed(todoError)
                return false
            }
        }

        return true
    }

    private func updateGitHubIssue() async throws {
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
        guard validateSettings() else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        issueCreationState = .inProgress

        do {
            try await repository.add(title: trimmedTitle, detail: detail, createIssue: true)
            issueCreationState = .succeeded
        } catch {
            let todoError = mapError(error)
            issueCreationState = .failed(todoError)
        }
    }

    func addWithoutIssue() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        await repository.addWithoutIssue(title: trimmedTitle, detail: detail)
    }

    /// Adds a new todo item if no confirmation is needed.
    ///
    /// - Returns: `true` if the item was added successfully, `false` if:
    ///   - A confirmation alert needs to be shown (`showConfirmationAlert` is enabled)
    ///   - An error occurred while creating a GitHub issue (sets `issueCreationState`)
    private func addNewItemIfNeeded() async -> Bool {
        if let repositorySettings = repositorySettings, repositorySettings.showConfirmationAlert {
            createIssueAlert = .presented(CreateIssueAlertContext())
            return false
        } else {
            issueCreationState = .inProgress

            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            do {
                try await repository.add(title: trimmedTitle, detail: detail, createIssue: true)
                issueCreationState = .succeeded
                return true
            } catch {
                let todoError = mapError(error)
                issueCreationState = .failed(todoError)
                return false
            }
        }
    }

    private func validateSettings() -> Bool {
        guard let service = service else {
            issueCreationState = .failed(
                .githubError(.incompleteSettings("GitHub service is not configured")))
            return false
        }

        let settings = service.repositorySettings
        if settings.owner.isEmpty {
            issueCreationState = .failed(
                .githubError(.incompleteSettings("GitHub owner is not configured")))
            return false
        }
        if settings.repo.isEmpty {
            issueCreationState = .failed(
                .githubError(.incompleteSettings("GitHub repository is not configured")))
            return false
        }
        if service.credentials.accessToken == nil
            || service.credentials.accessToken?.isEmpty == true
        {
            issueCreationState = .failed(
                .githubError(
                    .authenticationError(
                        "GitHub Personal Access Token is not saved. Please save your settings first."
                    )))
            return false
        }

        return true
    }

    private func mapError(_ error: Error) -> TodoError {
        if let todoError = error as? TodoError {
            return todoError
        }
        return .unknown(error.localizedDescription)
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
            .issueOperationOverlay(for: model.issueCreationState)
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
                                dismiss()
                            }
                        }
                    }
                    .disabled(
                        model.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || model.issueCreationState.isInProgress
                    )
                }
            }
            .alert(
                "Create GitHub Issue?",
                isPresented: Binding(
                    get: { model.createIssueAlert.isPresented },
                    set: { if !$0 { model.createIssueAlert = .dismissed } }
                )
            ) {
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
                        if model.issueCreationState.isSucceeded {
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
                    get: { model.issueCreationState.error != nil },
                    set: { if !$0 { model.issueCreationState = .idle } }
                )
            ) {
                Button("OK", role: .cancel) {
                    model.issueCreationState = .idle
                }
            } message: {
                if let error = model.issueCreationState.error {
                    Text(error.localizedDescription)
                }
            }
            #if canImport(UIKit)
                .popup(
                    isPresented: Binding(
                        get: { model.issueCreationState.isInProgress },
                        set: { _ in }
                    )
                ) {
                    ProgressView()
                    .scaleEffect(2)
                }
            #endif
        }
    }
}
