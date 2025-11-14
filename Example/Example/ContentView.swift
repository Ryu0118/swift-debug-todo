import SwiftUI
import DebugTodo

@MainActor
@Observable
final class ContentModel {
    init() {}
}

struct ContentView: View {
    let model: ContentModel

    init(model: ContentModel) {
        self.model = model
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Basic Storage") {
                    NavigationLink {
                        TodoListView(storage: InMemoryStorage())
                    } label: {
                        VStack(alignment: .leading) {
                            Text(StorageType.inMemory.rawValue)
                                .font(.headline)
                            Text("No GitHub integration")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        let fileURL = FileManager.default
                            .urls(for: .documentDirectory, in: .userDomainMask)[0]
                            .appendingPathComponent("todos.json")
                        TodoListView(storage: FileStorage(fileURL: fileURL))
                    } label: {
                        VStack(alignment: .leading) {
                            Text(StorageType.fileStorage.rawValue)
                                .font(.headline)
                            Text("No GitHub integration")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        TodoListView(storage: UserDefaultsStorage())
                    } label: {
                        VStack(alignment: .leading) {
                            Text(StorageType.userDefaults.rawValue)
                                .font(.headline)
                            Text("No GitHub integration")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("GitHub Integration") {
                    NavigationLink {
                        GitHubIntegrationView(model: GitHubIntegrationModel())
                    } label: {
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "link")
                                Text("With GitHub")
                                    .font(.headline)
                            }
                            Text("Automatic or manual issue creation")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Examples")
        }
    }
}

#Preview {
    ContentView(model: ContentModel())
}
