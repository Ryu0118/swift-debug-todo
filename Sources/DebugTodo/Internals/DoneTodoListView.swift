import SwiftUI

struct DoneTodoListView<S: Storage>: View {
    let repository: TodoRepository<S>
    #if os(iOS)
    @State private var editMode: EditMode = .inactive
    #endif
    @State private var showDeleteAllAlert = false
    @State private var selectedTodoIDs: Set<TodoItem.ID> = []

    init(repository: TodoRepository<S>) {
        self.repository = repository
    }

    var body: some View {
        Group {
            if repository.doneTodos.isEmpty {
                ContentUnavailableView(
                    "No Completed Todos",
                    systemImage: "checkmark.circle",
                    description: Text("Completed todos will appear here")
                )
            } else {
                List(selection: $selectedTodoIDs) {
                    ForEach(repository.doneTodos) { item in
                        NavigationLink {
                            AddEditTodoView(
                                repository: repository,
                                editingItem: item
                            )
                        } label: {
                            TodoRowView(
                                item: item,
                                onToggle: { repository.toggleDone(item) }
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                repository.delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        repository.delete(at: indexSet, from: repository.doneTodos)
                    }
                }
            }
        }
        .navigationTitle("Done")
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if editMode == .active && !selectedTodoIDs.isEmpty {
                    Button(role: .destructive) {
                        deleteSelectedTodos()
                    } label: {
                        Label("Delete Selected", systemImage: "trash")
                    }
                } else {
                    Button(role: .destructive) {
                        showDeleteAllAlert = true
                    } label: {
                        Label("Delete All", systemImage: "trash")
                    }
                    .disabled(repository.doneTodos.isEmpty)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .environment(\.editMode, $editMode)
        .onChange(of: editMode) { oldValue, newValue in
            if newValue == .inactive {
                selectedTodoIDs.removeAll()
            }
        }
        #endif
        .alert("Delete All Done Todos", isPresented: $showDeleteAllAlert) {
            Button("Delete", role: .destructive) {
                deleteAllDoneTodos()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete all done todos? This action cannot be undone.")
        }
    }

    private func deleteAllDoneTodos() {
        let todosToDelete = repository.doneTodos
        for todo in todosToDelete {
            repository.delete(todo)
        }
    }

    private func deleteSelectedTodos() {
        let todosToDelete = repository.doneTodos.filter { selectedTodoIDs.contains($0.id) }
        for todo in todosToDelete {
            repository.delete(todo)
        }
        selectedTodoIDs.removeAll()
    }
}
