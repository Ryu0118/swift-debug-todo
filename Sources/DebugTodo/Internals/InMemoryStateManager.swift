import Foundation

/// Manages in-memory state for todo items that have been toggled or deleted in the current session
@MainActor
@Observable
final class InMemoryStateManager {
    /// Set of item IDs that have been toggled in the current session
    private(set) var toggledItemIDs: Set<TodoItem.ID> = []

    /// Set of item IDs that have been deleted in the current session
    private(set) var deletedItemIDs: Set<TodoItem.ID> = []

    /// Marks an item as toggled
    func markAsToggled(_ itemID: TodoItem.ID) {
        toggledItemIDs.insert(itemID)
    }

    /// Unmarks an item as toggled
    func unmarkAsToggled(_ itemID: TodoItem.ID) {
        toggledItemIDs.remove(itemID)
    }

    /// Toggles the toggled state for an item
    func toggleToggledState(_ itemID: TodoItem.ID) {
        if toggledItemIDs.contains(itemID) {
            toggledItemIDs.remove(itemID)
        } else {
            toggledItemIDs.insert(itemID)
        }
    }

    /// Marks an item as deleted
    func markAsDeleted(_ itemID: TodoItem.ID) {
        deletedItemIDs.insert(itemID)
    }

    /// Checks if an item is toggled in memory
    func isToggled(_ itemID: TodoItem.ID) -> Bool {
        toggledItemIDs.contains(itemID)
    }

    /// Checks if an item is deleted in memory
    func isDeleted(_ itemID: TodoItem.ID) -> Bool {
        deletedItemIDs.contains(itemID)
    }

    /// Clears all in-memory state
    func clearAll() {
        toggledItemIDs.removeAll()
        deletedItemIDs.removeAll()
    }
}
