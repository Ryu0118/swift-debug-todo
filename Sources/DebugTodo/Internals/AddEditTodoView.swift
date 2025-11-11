import SwiftUI

struct AddEditTodoView<S: Storage>: View {
    @Environment(\.dismiss) private var dismiss
    let repository: TodoRepository<S>
    @State private var title: String
    @State private var detail: String

    private let editingItem: TodoItem?

    init(repository: TodoRepository<S>, editingItem: TodoItem? = nil) {
        self.repository = repository
        self.editingItem = editingItem
        self._title = State(initialValue: editingItem?.title ?? "")
        self._detail = State(initialValue: editingItem?.detail ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("", text: $title, axis: .vertical)
                }
                Section("Detail") {
                    TextEditor(text: $detail)
                }
            }
            .navigationTitle(editingItem == nil ? "New" : "Edit")
            .toolbar {
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

                ToolbarItem(placement: .confirmationAction) {
                    Button(editingItem == nil ? "Add" : "Save") {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        if let editingItem {
            var updatedItem = editingItem
            updatedItem.title = trimmedTitle
            updatedItem.detail = detail
            repository.update(updatedItem)
        } else {
            repository.add(title: trimmedTitle, detail: detail)
        }

        dismiss()
    }
}
