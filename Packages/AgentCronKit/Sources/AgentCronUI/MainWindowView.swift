import AgentCronCore
import SwiftUI

/// Layout metrics for ``MainWindowView``: the main window's minimum size from the design
/// lock (ADR-0009). Its default size is a scene setting, so it lives beside the
/// `Window` scene in `App/`.
private enum Layout {
    static let minWindowWidth: CGFloat = 860
    static let minWindowHeight: CGFloat = 560
}

/// The main window's root view — a placeholder until the Jobs, History, and General
/// sidebar replaces it (`docs/product/ux-flows.md` S2–S4).
///
/// Its words come from Core (`AppWindow.placeholder`), so the view has
/// no localizable literal of its own.
public struct MainWindowView: View {
    public var body: some View {
        Text(AppWindow.main.placeholder)
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minWidth: Layout.minWindowWidth, minHeight: Layout.minWindowHeight)
    }

    /// Creates the placeholder; it has no state to inject yet.
    public init() {
        // Public so `App/` can construct it; a synthesized initializer is internal.
    }
}

#Preview("Default") {
    MainWindowView()
}
