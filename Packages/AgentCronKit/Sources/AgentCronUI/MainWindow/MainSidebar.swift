import AgentCronCore
import SwiftUI

/// The main window's sidebar: one row per ``MainSection``. Selecting a row is the same
/// action as ⌘1–⌘3.
struct MainSidebar: View {
    let navigation: MainNavigationModel

    var body: some View {
        // A List selection can be cleared with ⌘-click; the window always shows a
        // section, so a cleared selection is ignored rather than sent to the model.
        let selection = Binding<MainSection?>(
            get: { navigation.section },
            set: { section in
                if let section {
                    navigation.select(section: section)
                }
            },
        )
        List(selection: selection) {
            ForEach(MainSection.allCases) { section in
                Label {
                    Text(section.title)
                } icon: {
                    Image(systemName: section.systemImage)
                        .symbolRenderingMode(.hierarchical)
                }
                .tag(section)
                .accessibilityIdentifier(section.sidebarIdentifier)
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("mainSidebar")
    }
}

extension MainSection {
    /// The SF Symbol beside the section's name in the sidebar and its placeholder
    /// (ADR-0009: hierarchical in the sidebar).
    var systemImage: String {
        switch self {
        case .jobs:
            "list.bullet.rectangle"

        case .history:
            "clock.arrow.circlepath"

        case .general:
            "gearshape"
        }
    }

    /// The sidebar row's accessibility identifier, a test contract never shown to anyone.
    var sidebarIdentifier: String {
        switch self {
        case .jobs:
            "sidebarJobs"

        case .history:
            "sidebarHistory"

        case .general:
            "sidebarGeneral"
        }
    }
}

#Preview("History selected") {
    MainSidebar(navigation: .preview(showing: .history))
        .frame(width: DesignLock.mainWindowSidebarWidth)
}
