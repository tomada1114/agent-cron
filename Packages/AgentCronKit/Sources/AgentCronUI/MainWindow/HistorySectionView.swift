import AgentCronCore
import SwiftUI

/// The main window's History section (`docs/product/ux-flows.md` S3): the History screen
/// over the model `App/` hands in, or the section's placeholder while none is wired.
struct HistorySectionView: View {
    let navigation: MainNavigationModel
    let history: HistoryModel?
    let stopRun: ((UUID) -> Void)?

    var body: some View {
        Group {
            if let history {
                HistoryScreenView(navigation: navigation, history: history, stopRun: stopRun)
            } else {
                SectionPlaceholder(section: .history)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("historySection")
    }
}

#Preview("Placeholder") {
    HistorySectionView(navigation: .preview(showing: .history), history: nil, stopRun: nil)
}
