import Foundation

enum StorageType: String, CaseIterable {
    case inMemory = "InMemory"
    case fileStorage = "FileStorage"
    case userDefaults = "UserDefaults"
}
