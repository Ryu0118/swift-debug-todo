import SwiftUI
import DebugTodo

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    TodoListView(storage: InMemoryStorage())
                } label: {
                    Text(StorageType.inMemory.rawValue)
                }

                NavigationLink {
                    let fileURL = FileManager.default
                        .urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("todos.json")
                    TodoListView(storage: FileStorage(fileURL: fileURL))
                } label: {
                    Text(StorageType.fileStorage.rawValue)
                }

                NavigationLink {
                    TodoListView(storage: UserDefaultsStorage())
                } label: {
                    Text(StorageType.userDefaults.rawValue)
                }
            }
            .navigationTitle("Storage Type")
        }
    }
}

#Preview {
    ContentView()
}
