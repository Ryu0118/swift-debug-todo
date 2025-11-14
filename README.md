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

**Note**: `TodoListView` uses SwiftUI's `NavigationLink` internally. You need to provide a navigation context:
- If presenting in a sheet or as a root view, wrap it in `NavigationStack`
- If pushing via `NavigationLink`, the parent's `NavigationStack` is sufficient

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

## Advanced: Custom Protocols

For advanced use cases, you can implement custom storage and integration backends:

### Custom Token Storage

Implement `GitHubTokenStorage` for custom token persistence:

```swift
public protocol GitHubTokenStorage: Sendable {
    func saveToken(_ token: String) throws
    func loadToken() throws -> String?
    func deleteToken() throws
}
```

### Custom Repository Settings Storage

Implement `GitHubRepositorySettingsStorage` for custom settings persistence:

```swift
public protocol GitHubRepositorySettingsStorage: Sendable {
    func save(_ settings: GitHubRepositorySettings) throws
    func load() throws -> GitHubRepositorySettings
}
```

### Custom Issue Creator

Implement `GitHubIssueCreatorProtocol` for custom GitHub integration or alternative issue tracking systems:

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
   - **Scopes**:
     - For **private repositories**: Check `repo` (Full control of private repositories)
     - For **public repositories only**: Check `public_repo` (Access to public repositories)
4. Click "Generate token"
5. **Important**: Copy the token immediately - you won't be able to see it again!

**Note**: This library only needs permission to create and update issues. The `repo` scope provides full repository access (required for private repos), while `public_repo` is sufficient if you only work with public repositories.

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
        TodoListView(
            storage: UserDefaultsStorage(),
            service: service,
            logLevel: .debug  // Optional: Enable debug logging
        )
    }
}
```

**Note**: The `logLevel` parameter is optional and can be used to enable logging for debugging purposes. Available levels: `.trace`, `.debug`, `.info`, `.notice`, `.warning`, `.error`, `.critical`.

**Navigation Context**: Since `TodoListView` uses `NavigationLink` for the settings view:
- Wrap in `NavigationStack` if presenting as a root view or in a sheet
- No wrapper needed if already inside a navigation hierarchy (e.g., pushed via `NavigationLink`)

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
        TodoListView(
            storage: UserDefaultsStorage(),
            service: service
        )
    }
}
```

**First Time Setup:**

1. Tap the settings icon (gear) in the toolbar - it appears automatically!
2. Paste your **Personal Access Token** (generated from GitHub)
3. Enter the repository **Owner** and **Repo** name
4. (Optional) Toggle **"Show confirmation alert"** - When enabled, you'll see a confirmation dialog before creating GitHub issues for new todos
5. Tap "Save"

All credentials are securely stored in Keychain and will persist across app launches.

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
