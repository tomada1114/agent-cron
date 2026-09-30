import AgentCronCore
import SwiftUI

/// The Jobs screen's list: one row per saved job, in ``JobListModel/rows``' order, or the
/// empty state when there is none (`docs/design/ux-guidelines.md` › States).
struct JobListView: View {
    let list: JobListModel
    let navigation: MainNavigationModel

    var body: some View {
        // Clicking a row asks the model; with unsaved edits it keeps the current row
        // selected and asks first, which this getter then shows.
        let selection = Binding<UUID?>(
            get: { list.selectedJobID },
            set: { list.selectionRequested(jobID: $0) },
        )
        // Next-run times are read against the clock, which observation does not track.
        TimelineView(.everyMinute) { _ in
            List(selection: selection) {
                ForEach(list.rows) { row in
                    JobListRowView(row: row, status: list.status(of: row))
                        .tag(row.id as UUID?)
                }
            }
            .listStyle(.inset)
        }
        .overlay {
            if list.jobs.isEmpty {
                emptyState
            }
        }
        .accessibilityIdentifier("jobList")
    }

    @ViewBuilder private var emptyState: some View {
        if list.storageError != nil {
            ContentUnavailableView {
                Label {
                    Text(JobsScreenText.loadFailed)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .accessibilityIdentifier("jobListLoadFailed")
        } else {
            ContentUnavailableView {
                Label {
                    Text(JobsScreenText.emptyTitle)
                } icon: {
                    Image(systemName: "list.bullet.rectangle")
                        .symbolRenderingMode(.hierarchical)
                }
            } description: {
                Text(JobsScreenText.emptyDescription)
            } actions: {
                Button {
                    navigation.newJob()
                } label: {
                    Text(MainMenuCommand.newJob.title)
                }
                .accessibilityIdentifier("emptyNewJobButton")
            }
            .accessibilityIdentifier("jobListEmpty")
        }
    }
}
