import Testing

@testable import DebugTodo

@Suite("DataState Tests")
struct DataStateTests {
    @Test("Idle state has no value")
    func idleStateHasNoValue() {
        let state: DataState<String, TodoError> = .idle
        #expect(state.value == nil)
        #expect(!state.isLoading)
        #expect(!state.hasValue)
    }

    @Test("Loading state preserves previous value")
    func loadingStatePreservesPreviousValue() {
        let state: DataState<String, TodoError> = .loading("previous")
        #expect(state.value == "previous")
        #expect(state.isLoading)
        #expect(state.hasValue)
    }

    @Test("Loading state without previous value")
    func loadingStateWithoutPreviousValue() {
        let state: DataState<String, TodoError> = .loading(nil)
        #expect(state.value == nil)
        #expect(state.isLoading)
        #expect(!state.hasValue)
    }

    @Test("Loaded state has value")
    func loadedStateHasValue() {
        let state: DataState<String, TodoError> = .loaded("data")
        #expect(state.value == "data")
        #expect(!state.isLoading)
        #expect(state.hasValue)
    }

    @Test("Failed state preserves previous value and error")
    func failedStatePreservesPreviousValueAndError() {
        let error = TodoError.validationError("test")
        let state: DataState<String, TodoError> = .failed(error, "previous")
        #expect(state.value == "previous")
        #expect(state.error == error)
        #expect(!state.isLoading)
    }

    @Test("Failed state without previous value")
    func failedStateWithoutPreviousValue() {
        let error = TodoError.validationError("test")
        let state: DataState<String, TodoError> = .failed(error, nil)
        #expect(state.value == nil)
        #expect(state.error == error)
        #expect(!state.isLoading)
        #expect(!state.hasValue)
    }

    @Test("Map transforms value in loaded state")
    func mapTransformsValueInLoadedState() {
        let state: DataState<Int, TodoError> = .loaded(5)
        let mapped = state.map { $0 * 2 }
        #expect(mapped.value == 10)
    }

    @Test("Map transforms value in loading state")
    func mapTransformsValueInLoadingState() {
        let state: DataState<Int, TodoError> = .loading(5)
        let mapped = state.map { $0 * 2 }
        #expect(mapped.value == 10)
        #expect(mapped.isLoading)
    }

    @Test("Map transforms value in failed state")
    func mapTransformsValueInFailedState() {
        let error = TodoError.validationError("test")
        let state: DataState<Int, TodoError> = .failed(error, 5)
        let mapped = state.map { $0 * 2 }
        #expect(mapped.value == 10)
        #expect(mapped.error == error)
    }

    @Test("Map preserves idle state")
    func mapPreservesIdleState() {
        let state: DataState<Int, TodoError> = .idle
        let mapped = state.map { $0 * 2 }
        #expect(mapped.value == nil)
        #expect(!mapped.isLoading)
    }

    @Test("Error property returns nil for non-failed states")
    func errorPropertyReturnsNilForNonFailedStates() {
        let idleState: DataState<String, TodoError> = .idle
        let loadingState: DataState<String, TodoError> = .loading("test")
        let loadedState: DataState<String, TodoError> = .loaded("test")

        #expect(idleState.error == nil)
        #expect(loadingState.error == nil)
        #expect(loadedState.error == nil)
    }
}
