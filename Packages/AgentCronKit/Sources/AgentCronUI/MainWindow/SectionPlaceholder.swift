import AgentCronCore
import SwiftUI

/// What a section shows until its screen exists: its name and a line saying what will
/// appear, in the system's empty-state layout.
struct SectionPlaceholder: View {
    let section: MainSection

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(section.title)
            } icon: {
                Image(systemName: section.systemImage)
                    .symbolRenderingMode(.hierarchical)
            }
        } description: {
            Text(section.placeholder)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Jobs") {
    SectionPlaceholder(section: .jobs)
}
