import Foundation
import Observation

@Observable
final class TodoRepository<S: Storage> {
    private let storage: S
    private(set) var items: [TodoItem] = []

    init(storage: S) {
        self.storage = storage
        loadItems()
    }

    var activeTodos: [TodoItem] {
        items.filter { !$0.isDone }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var doneTodos: [TodoItem] {
        items.filter { $0.isDone }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func add(title: String, detail: String = "") {
        let item = TodoItem(title: title, detail: detail)
        items.append(item)
        saveItems()
    }

    func update(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        var updatedItem = item
        updatedItem.updatedAt = Date()
        items[index] = updatedItem
        saveItems()
    }

    func delete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }

    func delete(at offsets: IndexSet, from todos: [TodoItem]) {
        let idsToDelete = offsets.map { todos[$0].id }
        items.removeAll { idsToDelete.contains($0.id) }
        saveItems()
    }

    func toggleDone(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        items[index].isDone.toggle()
        items[index].updatedAt = Date()
        saveItems()
    }

    private func loadItems() {
        do {
            items = try storage.load()
        } catch {
            print("Failed to load items: \(error)")
            items = []
        }
    }

    private func saveItems() {
        do {
            try storage.save(items)
        } catch {
            print("Failed to save items: \(error)")
        }
    }
}
