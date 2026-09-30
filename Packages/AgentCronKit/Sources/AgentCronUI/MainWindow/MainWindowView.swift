import AgentCronCore
import SwiftUI

/// The main window's shell: a sidebar of Jobs, History, and General beside the section it
/// selects (`docs/product/ux-flows.md` S2–S4).
///
/// The shell decides nothing: which section shows, and what each has selected, is
/// ``MainNavigationModel``'s. Each section is its own view — ``JobsSectionView``,
/// ``HistorySectionView``, ``GeneralSectionView`` — so the screens that fill them (#21,
/// #24, #25) each replace one file. The sidebar is the collapsible column: at the
/// window's minimum width it is what gives way (⌃⌘S brings it back), never the section.
public struct MainWindowView: View {
    private let navigation: MainNavigationModel

    public var body: some View {
        NavigationSplitView {
            MainSidebar(navigation: navigation)
                .navigationSplitViewColumnWidth(DesignLock.mainWindowSidebarWidth)
        } detail: {
            switch navigation.section {
            case .jobs:
                JobsSectionView()

            case .history:
                HistorySectionView()

            case .general:
                GeneralSectionView()
            }
        }
        .frame(
            minWidth: DesignLock.mainWindowMinWidth,
            minHeight: DesignLock.mainWindowMinHeight,
        )
    }

    /// Creates the shell over `navigation`, which `App/` owns for the app's lifetime
    /// because the main menu's commands act on it while the window is closed too.
    public init(navigation: MainNavigationModel) {
        self.navigation = navigation
    }
}

extension MainNavigationModel {
    /// A model on `section` over a throwaway defaults suite, so a preview never writes
    /// into the real app's stored navigation.
    @MainActor
    static func preview(showing section: MainSection) -> MainNavigationModel {
        let model =
            MainNavigationModel(defaults: UserDefaults(suiteName: "AgentCronPreview") ?? .standard)
        model.select(section: section)
        return model
    }
}

#Preview("Jobs") {
    MainWindowView(navigation: .preview(showing: .jobs))
}

#Preview("History") {
    MainWindowView(navigation: .preview(showing: .history))
}

#Preview("General") {
    MainWindowView(navigation: .preview(showing: .general))
}

#Preview("Dark") {
    MainWindowView(navigation: .preview(showing: .jobs))
        .preferredColorScheme(.dark)
}
