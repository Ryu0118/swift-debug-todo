import SwiftUI

/// Reusable alert buttons for toggling todo items with GitHub issues.
struct ToggleAlertButtons: View {
    let issueState: GitHubIssueState?
    let onToggleWithUpdate: (IssueStateReason?) async -> Void
    let onToggleWithoutUpdate: () async -> Void
    let onCancel: () -> Void

    var body: some View {
        if issueState == .open {
            Button("Check & Close as Completed") {
                Task {
                    await onToggleWithUpdate(.completed)
                }
            }
            Button("Check & Close as Not Planned") {
                Task {
                    await onToggleWithUpdate(.notPlanned)
                }
            }
            Button("Check & Close as Duplicate") {
                Task {
                    await onToggleWithUpdate(.duplicate)
                }
            }
            Button("Check Only") {
                Task {
                    await onToggleWithoutUpdate()
                }
            }
        } else {
            Button("Uncheck & Reopen") {
                Task {
                    await onToggleWithUpdate(.reopened)
                }
            }
            Button("Uncheck Only") {
                Task {
                    await onToggleWithoutUpdate()
                }
            }
        }
        Button("Cancel", role: .cancel) {
            onCancel()
        }
    }
}
