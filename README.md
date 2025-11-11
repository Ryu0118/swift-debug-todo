# DebugTodo

A SwiftUI-based todo list library for debugging and development purposes.

DebugTodo provides a simple todo list interface with pluggable storage backends. It's designed for developers who need a quick way to manage debug tasks, feature flags, or temporary notes during development.

## Usage

### Basic Example

```swift
import SwiftUI
import DebugTodo

struct ContentView: View {
    var body: some View {
        TodoListView(storage: UserDefaultsStorage(
            userDefaults: .standard,
            key: "myCustomTodos"
        ))
    }
}
```

### Storage Options

#### 1. InMemory Storage
Volatile storage - data is lost when the app terminates.

```swift
TodoListView(storage: InMemoryStorage())
```

#### 2. File Storage
Persistent JSON file storage.

```swift
let fileURL = FileManager.default
    .urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("todos.json")
TodoListView(storage: FileStorage(fileURL: fileURL))
```

#### 3. UserDefaults Storage
Standard UserDefaults persistence.

```swift
// Default configuration
TodoListView(storage: UserDefaultsStorage())

// Custom UserDefaults instance
let groupDefaults = UserDefaults(suiteName: "group.com.example.app")!
TodoListView(storage: UserDefaultsStorage(userDefaults: groupDefaults))

// Custom storage key
TodoListView(storage: UserDefaultsStorage(
    userDefaults: .standard,
    key: "myCustomTodos"
))
```

## Custom Storage

Implement the `Storage` protocol to create your own storage backend:

```swift
public protocol Storage: Sendable {
    func save(_ items: [TodoItem]) throws
    func load() throws -> [TodoItem]
    func delete() throws
}
```

## Example App

See the `Example/` directory for a complete sample app demonstrating all storage implementations.

## Requirements

- **Swift**: 6.2+
- **Xcode**: 26.0+
- **Platforms**:
  - iOS 17.0+
  - macOS 14.0+
  - visionOS 1.0+
  - Mac Catalyst 17.0+
  - tvOS 17.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/swift-debug-todo.git", from: "0.1.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select the version you want to use
