import AgentCronCore
import SwiftUI

/// The History section's screen (`docs/product/ux-flows.md` S3): the run list beside the
/// selected run's detail.
///
/// It decides nothing: grouping, filtering, and formatting are ``HistoryModel``'s, and
/// the selected run is kept in step with ``MainNavigationModel``, which remembers it
/// across launches. Stopping a run is the runner's, so it arrives as `stopRun`.
struct HistoryScreenView: View {
    private enum Layout {
        /// ux-flows S3: the list is at least 280 pt and the detail at least 420 pt.
        static let listMinWidth: CGFloat = 280
        static let listMaxWidth: CGFloat = 360
        static let detailMinWidth: CGFloat = 420
    }

    let navigation: MainNavigationModel
    let history: HistoryModel
    let stopRun: ((UUID) -> Void)?

    var body: some View {
        // An HStack rather than an HSplitView, as on the Jobs screen: the split view does
        // not honor the detail's minimum width when it hands out the initial widths.
        HStack(spacing: 0) {
            HistoryListView(history: history, navigation: navigation, select: select)
                .frame(minWidth: Layout.listMinWidth, maxWidth: Layout.listMaxWidth)
            Divider()
            detailPane
                .frame(minWidth: Layout.detailMinWidth, maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
        .onAppear {
            history.select(runID: navigation.selectedRunID)
        }
    }

    @ViewBuilder private var detailPane: some View {
        if let detail = history.detail {
            HistoryRunDetailView(
                detail: detail,
                openJob: { navigation.showJob(detail.run.jobID) },
                stop: stopRun.map { stop in { stop(detail.run.id) } },
            )
            .id(detail.run.id)
        } else if history.emptyState != nil {
            // The list's empty state says it all, and the detail stays blank.
            Color.clear
        } else {
            ContentUnavailableView {
                Text(HistoryScreenText.noSelection)
            }
            .accessibilityIdentifier("historyNoSelection")
        }
    }

    private func select(_ runID: UUID?) {
        history.select(runID: runID)
        navigation.select(runID: runID)
    }
}
