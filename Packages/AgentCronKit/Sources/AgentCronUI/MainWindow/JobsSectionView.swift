import AgentCronCore
import SwiftUI

/// The main window's Jobs section (`docs/product/ux-flows.md` S2): the Jobs screen over the
/// job list `App/` hands in, or the section's placeholder while none is wired.
struct JobsSectionView: View {
    let navigation: MainNavigationModel
    let list: JobListModel?
    let notifications: RunNotificationController?

    var body: some View {
        Group {
            if let list {
                JobsScreenView(navigation: navigation, list: list, notifications: notifications)
            } else {
                SectionPlaceholder(section: .jobs)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("jobsSection")
    }
}

#Preview("Placeholder") {
    JobsSectionView(navigation: .preview(showing: .jobs), list: nil, notifications: nil)
}
