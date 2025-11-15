# DebugTodo

A SwiftUI-based todo list library for debugging and development purposes with optional GitHub integration.

## Usage

### Basic Usage (Without GitHub Integration)

```swift
import SwiftUI
import DebugTodo

struct ContentView: View {
    var body: some View {
        NavigationStack {
            TodoListView(storage: UserDefaultsStorage())
        }
    }
}
```

### With GitHub Integration

```swift
import SwiftUI
import DebugTodo

struct ContentView: View {
    @State private var service = GitHubService()

    var body: some View {
        NavigationStack {
            TodoListView(
                storage: UserDefaultsStorage(),
                service: service
            )
        }
    }
}
```

**Setup**: Tap the settings icon (gear) in the toolbar, then enter:
- **Personal Access Token** (required scope: `repo` for private repos, `public_repo` for public repos only)
- **Owner** and **Repo** name

**Note**: `TodoListView` uses SwiftUI's `NavigationLink` internally. Wrap it in `NavigationStack` if presenting as a root view or in a sheet

## Storage Options

**InMemory Storage** (data lost on app termination):
```swift
TodoListView(storage: InMemoryStorage())
```

**File Storage** (JSON file persistence):
```swift
let fileURL = FileManager.default
    .urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("todos.json")
TodoListView(storage: FileStorage(fileURL: fileURL))
```

**UserDefaults Storage**:
```swift
TodoListView(storage: UserDefaultsStorage())

// Custom key
TodoListView(storage: UserDefaultsStorage(
    userDefaults: .standard,
    key: "myCustomTodos"
))
```

## Requirements

- **Swift**: 6.2+
- **Xcode**: 26.0+
- **Platforms**:
  - iOS 17.0+
  - macOS 14.0+
  - visionOS 1.0+
  - Mac Catalyst 17.0+

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

## Example App

See the `Example/` directory for a complete sample app demonstrating all storage implementations and GitHub integration.

## Advanced Configuration

### Custom Keychain Configuration

```swift
struct ContentView: View {
    @State private var service: GitHubService = {
        let tokenStorage = KeychainTokenStorage(
            service: "com.myapp.github",
            key: "myAccessToken"
        )

        let repositorySettingsStorage = KeychainRepositorySettingsStorage(
            service: "com.myapp.github",
            ownerKey: "myOwner",
            repoKey: "myRepo",
            showConfirmationAlertKey: "myShowConfirmation"
        )

        return GitHubService(
            tokenStorage: tokenStorage,
            repositorySettingsStorage: repositorySettingsStorage
        )
    }()

    var body: some View {
        NavigationStack {
            TodoListView(
                storage: UserDefaultsStorage(),
                service: service
            )
        }
    }
}
```

### Debug Logging

```swift
TodoListView(
    storage: UserDefaultsStorage(),
    service: service,
    logLevel: .debug  // Available: .trace, .debug, .info, .notice, .warning, .error, .critical
)
```

### Custom Protocols

Implement these protocols for custom backends:

**Storage Protocol**:
```swift
public protocol Storage: Sendable {
    func save(_ items: [TodoItem]) async throws
    func load() async throws -> [TodoItem]
    func delete() async throws
}
```

**GitHub Token Storage**:
```swift
public protocol GitHubTokenStorage: Sendable {
    func saveToken(_ token: String) async throws
    func loadToken() async throws -> String?
    func deleteToken() async throws
}
```

**GitHub Issue Creator**:
```swift
public protocol GitHubIssueCreatorProtocol: Sendable {
    func createIssue(for item: TodoItem) async throws -> GitHubIssue?
    func updateIssueState(
        owner: String,
        repo: String,
        issueNumber: Int,
        state: String,
        stateReason: String?
    ) async throws -> GitHubIssue?
    func updateIssueContent(
        owner: String,
        repo: String,
        issueNumber: Int,
        title: String,
        body: String?
    ) async throws -> GitHubIssue?
}
```
