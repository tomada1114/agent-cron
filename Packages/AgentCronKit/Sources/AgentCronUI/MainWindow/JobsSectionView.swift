import AgentCronCore
import SwiftUI

/// The main window's Jobs section (`docs/product/ux-flows.md` S2) — a placeholder until
/// the job list and editor (#21) replace it.
struct JobsSectionView: View {
    var body: some View {
        SectionPlaceholder(section: .jobs)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("jobsSection")
    }
}

#Preview("Placeholder") {
    JobsSectionView()
}
