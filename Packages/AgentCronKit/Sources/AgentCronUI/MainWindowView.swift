import AgentCronCore
import SwiftUI

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
            .frame(
                minWidth: DesignLock.mainWindowMinWidth,
                minHeight: DesignLock.mainWindowMinHeight,
            )
    }

    /// Creates the placeholder; it has no state to inject yet.
    public init() {
        // Public so `App/` can construct it; a synthesized initializer is internal.
    }
}

#Preview("Default") {
    MainWindowView()
}
