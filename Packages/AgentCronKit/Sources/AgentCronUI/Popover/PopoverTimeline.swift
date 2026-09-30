import AgentCronCore
import SwiftUI

/// Today's rows, the next run, or the empty state; only this part scrolls.
struct PopoverTimeline: View {
    let model: PopoverModel
    let actions: PopoverActions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let empty = model.emptyState {
                    emptyView(empty)
                } else {
                    rows
                }
            }
            .padding(DesignLock.popoverPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("popoverTimeline")
    }

    @ViewBuilder private var rows: some View {
        let timeline = model.rows
        ForEach(Array(timeline.enumerated()), id: \.element.id) { index, row in
            if index == 0 || timeline[index - 1].day != row.day {
                Text(row.day.label ?? PopoverText.today)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, index == 0 ? 0 : DesignLock.spacingS)
                    .accessibilityAddTraits(.isHeader)
            }
            PopoverRowView(row: row, actions: actions)
        }
    }

    private func emptyView(_ empty: PopoverEmptyState) -> some View {
        VStack(alignment: .leading, spacing: DesignLock.spacingS) {
            Text(empty.message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            switch empty {
            case .noJobs:
                Button(PopoverText.createFirstJob, action: actions.newJob)
                    .accessibilityIdentifier("popoverCreateFirstJob")

            case .allPaused:
                Button(PopoverText.openJobs) {
                    actions.open(.jobs)
                }
                .accessibilityIdentifier("popoverOpenJobs")

            case .nothingToday:
                EmptyView()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("popoverEmptyState")
    }
}
