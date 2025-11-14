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

## GitHub Integration

DebugTodo supports automatic GitHub issue creation when new todos are added. This feature uses Personal Access Token (PAT) authentication, which is simple to set up and secure.

All credentials are securely stored in the Keychain.

### Setup

#### 1. Generate a Personal Access Token

1. Go to [GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)](https://github.com/settings/tokens)
2. Click "Generate new token" → "Generate new token (classic)"
3. Fill in the details:
   - **Note**: A description for this token (e.g., "DebugTodo App")
   - **Expiration**: Choose an expiration period (recommended: 90 days or custom)
   - **Scopes**: Check `repo` (Full control of private repositories)
     - This includes `repo:status`, `repo_deployment`, `public_repo`, `repo:invite`, and `security_events`
4. Click "Generate token"
5. **Important**: Copy the token immediately - you won't be able to see it again!

### Security

All sensitive data (access tokens and repository information) is stored securely in the Keychain. The library uses `KeychainStorage` to ensure credentials persist across app launches and remain protected.

### Usage

#### Basic Usage (No GitHub Integration)

```swift
import SwiftUI
import DebugTodo

struct ContentView: View {
    var body: some View {
        TodoListView(storage: UserDefaultsStorage())
    }
}
```

#### With GitHub Integration

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

That's it! The settings button (gear icon) will automatically appear in the toolbar.

**Custom Keychain Configuration:**

You can customize the Keychain service name and keys:

```swift
struct ContentView: View {
    @State private var service: GitHubService = {
        let tokenStorage = KeychainTokenStorage(
            service: "com.myapp.github",
            key: "myAccessToken"
        )

        let configStorage = KeychainConfigurationStorage(
            service: "com.myapp.github",
            ownerKey: "myOwner",
            repoKey: "myRepo"
        )

        return GitHubService(
            tokenStorage: tokenStorage,
            configurationStorage: configStorage
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

**First Time Setup:**

1. Tap the settings icon (gear) in the toolbar - it appears automatically!
2. Paste your **Personal Access Token** (generated from GitHub)
3. Enter the repository **Owner** and **Repo** name
4. Tap "Save"

All credentials are securely stored in Keychain and will persist across app launches.

#### Manually Creating Issues

You can also manually trigger issue creation:

```swift
let service = GitHubService()

Task {
    do {
        let issue = try await service.issueCreator.createIssue(for: todoItem)
        print("Created issue: \(issue?.htmlUrl ?? "nil")")
    } catch {
        print("Failed to create issue: \(error)")
    }
}
```

### Disabling GitHub Integration

To use TodoListView without GitHub integration, simply don't provide the `issueCreator` parameter (it defaults to `NoOpGitHubIssueCreator`):

```swift
TodoListView(storage: UserDefaultsStorage())
```

This is perfect for development/testing or if you don't need the GitHub integration feature.

## Example App

See the `Example/` directory for a complete sample app demonstrating all storage implementations and GitHub integration.

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
