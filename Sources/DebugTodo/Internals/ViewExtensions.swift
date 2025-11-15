import SwiftUI

#if canImport(UIKit)
    import FullscreenPopup
#endif

extension View {
    /// Display loading overlay based on DataState
    @ViewBuilder
    public func loadingOverlay<Value, ErrorType>(
        for state: DataState<Value, ErrorType>
    ) -> some View {
        self
            .disabled(state.isLoading)
            .blur(radius: state.isLoading ? 3 : 0)
            .overlay {
                if state.isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        ProgressView()
                    }
                }
            }
    }

    /// Display loading overlay based on IssueOperationState
    @ViewBuilder
    public func issueOperationOverlay<ErrorType>(
        for state: IssueOperationState<ErrorType>
    ) -> some View {
        #if os(macOS)
            self
                .disabled(state.isInProgress)
                .blur(radius: state.isInProgress ? 3 : 0)
                .overlay {
                    if state.isInProgress {
                        ZStack {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            ProgressView()
                        }
                    }
                }
        #elseif canImport(UIKit)
            self
                .popup(
                    isPresented: Binding(
                        get: { state.isInProgress },
                        set: { _ in }
                    )
                ) {
                    ProgressView()
                        .scaleEffect(2)
                }
        #else
            self
        #endif
    }
}
