import AgentCronCore
import SwiftUI

/// The Jobs section's screen (`docs/product/ux-flows.md` S2): the job list beside the
/// selected job's editor.
///
/// It decides nothing. The list and editor are ``JobListModel``'s; which job is selected
/// is kept in step with ``MainNavigationModel``, which remembers it across launches and
/// carries the main menu's New Job, Enable / Disable, and Delete… here as requests.
struct JobsScreenView: View {
    private enum Layout {
        /// ux-flows S2: the list is at least 240 pt and the detail at least 420 pt, so
        /// both fit beside the 180 pt sidebar at the window's 860 pt minimum.
        static let listMinWidth: CGFloat = 240
        static let listMaxWidth: CGFloat = 320
        static let detailMinWidth: CGFloat = 420
    }

    let navigation: MainNavigationModel
    let list: JobListModel
    let notifications: RunNotificationController?

    var body: some View {
        // An HStack rather than an HSplitView: the split view hands out its initial
        // widths without honoring the detail's minimum, which squeezed the sidebar.
        HStack(spacing: 0) {
            JobListView(list: list, navigation: navigation)
                .frame(minWidth: Layout.listMinWidth, maxWidth: Layout.listMaxWidth)
            Divider()
            detail
                .frame(minWidth: Layout.detailMinWidth, maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    navigation.newJob()
                } label: {
                    Label {
                        Text(MainMenuCommand.newJob.title)
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
                .help(Text(MainMenuCommand.newJob.title))
                .accessibilityIdentifier("newJobToolbarButton")
            }
        }
        .onAppear(perform: appeared)
        .onChange(of: navigation.pendingJobsScreenRequest) { _, request in
            handle(request)
        }
        .onChange(of: list.selectedJobID) { _, jobID in
            navigation.select(jobID: jobID)
        }
        .onChange(of: list.jobIDs) { _, jobIDs in
            navigation.knownJobsChanged(to: jobIDs)
        }
        .alert(
            Text(list.pendingDeletion?.title ?? JobsScreenText.deleteJob),
            isPresented: Binding(get: { list.pendingDeletion != nil }, set: { _ in
                // Only the alert's buttons answer it: each calls its own action.
            }),
            presenting: list.pendingDeletion,
        ) { _ in
            Button(role: .destructive) {
                list.deletionConfirmed()
            } label: {
                Text(JobsScreenText.delete)
            }
            .accessibilityIdentifier("confirmDeleteButton")
            Button(role: .cancel) {
                list.deletionCancelled()
            } label: {
                Text(JobsScreenText.cancel)
            }
        } message: { confirmation in
            Text(confirmation.message)
        }
    }

    @ViewBuilder private var detail: some View {
        if let editor = list.editor {
            JobEditorView(
                editor: editor,
                list: list,
                navigation: navigation,
                notificationAuthorization: notifications?.authorizationState,
            )
            .id(ObjectIdentifier(editor))
        } else if list.jobs.isEmpty {
            // No jobs: the list's empty state says it all, and the detail stays blank.
            Color.clear
        } else {
            ContentUnavailableView {
                Text(JobsScreenText.noSelection)
            }
            .accessibilityIdentifier("jobNoSelection")
        }
    }

    private func appeared() {
        list.screenAppeared(restoringSelection: navigation.selectedJobID)
        navigation.knownJobsChanged(to: list.jobIDs)
        handle(navigation.pendingJobsScreenRequest)
    }

    private func handle(_ request: JobsScreenRequest?) {
        guard let request else {
            return
        }
        list.menuCommandRequested(request.command)
        navigation.jobsScreenRequestHandled(request)
    }
}
