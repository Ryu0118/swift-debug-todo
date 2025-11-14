import SwiftUI
import DebugTodo

@MainActor
@Observable
final class GitHubIntegrationModel {
    var service: GitHubService

    init() {
        self.service = GitHubService()
    }
}

struct GitHubIntegrationView: View {
    @Bindable var model: GitHubIntegrationModel

    init(model: GitHubIntegrationModel) {
        self.model = model
    }

    var body: some View {
        TodoListView(
            storage: UserDefaultsStorage(
                userDefaults: .standard,
                key: "debugtodos"
            ),
            service: model.service
        )
        .navigationTitle("GitHub Integration")
    }
}

#Preview {
    NavigationStack {
        GitHubIntegrationView(model: GitHubIntegrationModel())
    }
}
