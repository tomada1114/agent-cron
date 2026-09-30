import AgentCronCore
import SwiftUI

/// The History list: the job and outcome filters over the runs grouped by day, newest
/// first, or the empty state the model names.
struct HistoryListView: View {
    let history: HistoryModel
    let navigation: MainNavigationModel
    let select: (UUID?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HistoryFilterBar(history: history)
                .padding(DesignLock.spacingS)
            Divider()
            content
        }
    }

    @ViewBuilder private var content: some View {
        switch history.emptyState {
        case .noRuns:
            ContentUnavailableView {
                Label {
                    Text(MainSection.history.title)
                } icon: {
                    Image(systemName: MainSection.history.systemImage)
                        .symbolRenderingMode(.hierarchical)
                }
            } description: {
                Text(HistoryEmptyState.noRuns.message)
            } actions: {
                Button {
                    navigation.select(section: .jobs)
                } label: {
                    Text(HistoryScreenText.openJobs)
                }
                .accessibilityIdentifier("historyOpenJobsButton")
            }
            .accessibilityIdentifier("historyEmpty")

        case .noMatches:
            ContentUnavailableView {
                Text(HistoryEmptyState.noMatches.message)
            } actions: {
                Button {
                    history.clearFilters()
                } label: {
                    Text(HistoryScreenText.clearFilters)
                }
                .accessibilityIdentifier("historyClearFiltersButton")
            }
            .accessibilityIdentifier("historyNoMatches")

        case nil:
            List(selection: Binding(
                get: { history.selectedRunID },
                set: { runID in select(runID) },
            )) {
                ForEach(history.groups) { group in
                    Section {
                        ForEach(group.rows) { row in
                            HistoryRowView(row: row)
                                .tag(row.id)
                        }
                    } header: {
                        Text(group.title)
                    }
                }
            }
            .listStyle(.inset)
            .accessibilityIdentifier("historyList")
        }
    }
}
