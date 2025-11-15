import SwiftUI

/// Reusable alert buttons for deleting todo items with GitHub issues.
struct DeleteAlertButtons: View {
    let onDeleteAndClose: (IssueStateReason) async -> Void
    let onDeleteOnly: () async -> Void
    let onCancel: () -> Void

    var body: some View {
        Button("Delete & Close as Completed") {
            Task {
                await onDeleteAndClose(.completed)
            }
        }
        Button("Delete & Close as Not Planned") {
            Task {
                await onDeleteAndClose(.notPlanned)
            }
        }
        Button("Delete & Close as Duplicate") {
            Task {
                await onDeleteAndClose(.duplicate)
            }
        }
        Button("Delete Only") {
            Task {
                await onDeleteOnly()
            }
        }
        Button("Cancel", role: .cancel) {
            onCancel()
        }
    }
}
