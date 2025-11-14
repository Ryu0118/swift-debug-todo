import SwiftUI

@MainActor
@Observable
final class TodoRowModel {
    let item: TodoItem
    let onToggle: () -> Void

    init(item: TodoItem, onToggle: @escaping () -> Void) {
        self.item = item
        self.onToggle = onToggle
    }
}

@available(iOS 17.0, macOS 14.0, visionOS 1.0, macCatalyst 17.0, *)
struct TodoRowView: View {
    @Environment(\.openURL) private var openURL

    let model: TodoRowModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                model.onToggle()
            } label: {
                Image(systemName: model.item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(model.item.isDone ? .blue : .gray)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .padding(8) // Expand tap area
            .contentShape(Rectangle()) // Make entire padded area tappable
            .padding(-8) // Remove visual padding while keeping tap area

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(model.item.title)
                        .font(.body)
                        .strikethrough(model.item.isDone)
                        .foregroundStyle(model.item.isDone ? .secondary : .primary)

                    if let issueNumber = model.item.gitHubIssueNumber {
                        Button {
                            if let urlString = model.item.gitHubIssueUrl,
                               let url = URL(string: urlString) {
                                openURL(url)
                            }
                        } label: {
                            Text("#\(issueNumber)")
                                .font(.caption)
                                .foregroundStyle(.blue)
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
