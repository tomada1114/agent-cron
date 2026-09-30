import AgentCronCore
import SwiftUI

/// The main window's History section (`docs/product/ux-flows.md` S3) — a placeholder until
/// the run list and run detail (#24) replace it.
struct HistorySectionView: View {
    var body: some View {
        SectionPlaceholder(section: .history)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("historySection")
    }
}

#Preview("Placeholder") {
    HistorySectionView()
}
