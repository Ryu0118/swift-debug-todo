import SwiftUI

/// A view that displays the list of active todo items.
public struct TodoListView<S: Storage>: View {
    @State private var repository: TodoRepository<S>
    @State private var isShowingAddView = false
#if os(iOS)
    @State private var editMode: EditMode = .inactive
#endif
    
    /// Creates a new todo list view.
    ///
    /// - Parameter storage: The storage to use for persisting todo items.
    public init(storage: S) {
        self.repository = TodoRepository(storage: storage)
    }
    
    public var body: some View {
        Group {
            if repository.activeTodos.isEmpty {
                ContentUnavailableView(
                    "No Active Todos",
                    systemImage: "checklist",
                    description: Text("Add a new todo to get started")
                )
            } else {
                List {
                    ForEach(repository.activeTodos) { item in
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
                        repository.delete(at: indexSet, from: repository.activeTodos)
                    }
                }
            }
        }
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
#endif
            ToolbarItem(placement: .automatic) {
                HStack {
                    NavigationLink {
                        DoneTodoListView(repository: repository)
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    
                    Button {
                        isShowingAddView = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingAddView) {
            AddEditTodoView(repository: repository)
        }
#if os(iOS)
        .environment(\.editMode, $editMode)
#endif
    }
}
