import Foundation
import Testing

@testable import DebugTodo

@Suite("TodoRowModel Tests")
@MainActor
struct TodoRowModelTests {

    @Test("Initialize model with item and toggle callback")
    func initialize() {
        let item = TodoItem(title: "Test", detail: "Detail")
        var toggleCalled = false
        let onToggle = { toggleCalled = true }

        let model = TodoRowModel(item: item, onToggle: onToggle)

        #expect(model.item.id == item.id)
        #expect(model.item.title == "Test")
        #expect(model.item.detail == "Detail")

        model.onToggle()
        #expect(toggleCalled == true)
    }

    @Test("Toggle callback is executed when called")
    func toggleCallbackExecuted() {
        var callCount = 0
        let item = TodoItem(title: "Test", detail: "")
        let model = TodoRowModel(item: item, onToggle: { callCount += 1 })

        model.onToggle()
        model.onToggle()

        #expect(callCount == 2)
    }

    @Test("Model with completed item")
    func modelWithCompletedItem() {
        var item = TodoItem(title: "Completed", detail: "")
        item.isDone = true

        let model = TodoRowModel(item: item, onToggle: {})

        #expect(model.item.isDone == true)
    }

    @Test("Model with GitHub issue URL")
    func modelWithGitHubIssue() {
        var item = TodoItem(title: "Test", detail: "")
        item.gitHubIssueUrl = "https://github.com/test/repo/issues/42"

        let model = TodoRowModel(item: item, onToggle: {})

        #expect(model.item.gitHubIssueUrl == "https://github.com/test/repo/issues/42")
        #expect(model.item.gitHubIssueNumber == 42)
    }
}
