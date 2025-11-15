import SwiftUI

@MainActor
@Observable
final class TodoRowModel {
    let item: TodoItem
    let onToggle: () -> Void
    let effectiveDoneState: Bool
    let issueState: GitHubIssueState?

    init(item: TodoItem, onToggle: @escaping () -> Void, effectiveDoneState: Bool? = nil, issueState: GitHubIssueState? = nil) {
        self.item = item
        self.onToggle = onToggle
        self.effectiveDoneState = effectiveDoneState ?? item.isDone
        self.issueState = issueState
    }
}

struct TodoRowView: View {
    @Environment(\.openURL) private var openURL

    let model: TodoRowModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                model.onToggle()
            } label: {
                Image(systemName: model.effectiveDoneState ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(model.effectiveDoneState ? .blue : .gray)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .padding(8)  // Expand tap area
            .contentShape(Rectangle())  // Make entire padded area tappable
            .padding(-8)  // Remove visual padding while keeping tap area

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(model.item.title)
                        .font(.body)
                        .strikethrough(model.effectiveDoneState)
                        .foregroundStyle(model.effectiveDoneState ? .secondary : .primary)

                    if let issueNumber = model.item.gitHubIssueNumber {
                        Button {
                            if let urlString = model.item.gitHubIssueUrl,
                                let url = URL(string: urlString)
                            {
                                openURL(url)
                            }
                        } label: {
                            if let state = model.issueState {
                                Text("#\(issueNumber) (\(state.displayText))")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            } else {
                                Text("#\(issueNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !model.item.detail.isEmpty {
                    Text(model.item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
