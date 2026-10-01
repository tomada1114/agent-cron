import AgentCronCore
import SwiftUI

/// The Jobs screen's detail pane (`docs/product/ux-flows.md` S2): the header, then the
/// Task, Schedule, Agent, and Notifications sections over one ``JobEditorModel``.
///
/// It owns only keyboard focus, because the editor's validation timing hangs on it:
/// focus leaving a field is ``JobEditorModel/fieldLostFocus(_:)``, a refused save moves
/// focus to the first invalid field, and while any field has focus the Job menu's
/// Delete… is off (``MainNavigationModel/editorFocusChanged(isFocused:)``) so ⌘⌫ edits
/// the text instead.
struct JobEditorView: View {
    let editor: JobEditorModel
    let list: JobListModel
    let navigation: MainNavigationModel
    let notificationAuthorization: NotificationAuthorizationState?

    @FocusState private var focusedField: JobEditorField?

    var body: some View {
        VStack(spacing: 0) {
            JobEditorHeader(
                editor: editor,
                status: status,
                save: save,
                runNow: navigation.runSelectedJobNow,
                stop: navigation.stopSelectedJob,
            )
            .padding(.horizontal, DesignLock.spacingL)
            .padding(.vertical, DesignLock.spacingM)
            Divider()
            Form {
                JobTaskSection(editor: editor, focus: $focusedField)
                JobScheduleSection(editor: editor, focus: $focusedField)
                JobAgentSection(editor: editor, focus: $focusedField)
                JobNotifySection(editor: editor, authorization: notificationAuthorization)
                if !editor.isNew {
                    deleteRow
                }
            }
            .formStyle(.grouped)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("jobEditor")
        .onChange(of: focusedField) { oldField, newField in
            if let oldField {
                editor.fieldLostFocus(oldField)
            }
            navigation.editorFocusChanged(isFocused: newField != nil)
        }
        .onDisappear {
            navigation.editorFocusChanged(isFocused: false)
        }
        .alert(
            Text(editor.saveChangesTitle),
            isPresented: Binding(get: { list.pendingSelection != nil }, set: { _ in
                // Only the alert's buttons answer it: each calls its own action.
            }),
        ) {
            Button {
                saveBeforeLeaving()
            } label: {
                Text(JobsScreenText.save)
            }
            .keyboardShortcut(.defaultAction)
            Button(role: .destructive) {
                list.unsavedChangesDiscarded()
            } label: {
                Text(JobsScreenText.dontSave)
            }
            Button(role: .cancel) {
                list.unsavedChangesCancelled()
            } label: {
                Text(JobsScreenText.cancel)
            }
        }
    }

    private var status: LocalizedStringResource? {
        list.selectedRow.map(list.status(of:))
    }

    private var deleteRow: some View {
        Section {
            HStack {
                Spacer()
                Button(role: .destructive) {
                    list.deleteRequested(jobID: editor.draft.id)
                } label: {
                    Text(JobsScreenText.deleteJob)
                }
                .accessibilityIdentifier("deleteJobButton")
            }
        }
    }

    private func save() {
        if case let .invalid(firstField) = editor.save() {
            focusedField = firstField
        }
    }

    private func saveBeforeLeaving() {
        guard case let .invalid(firstField) = list.unsavedChangesSaved() else {
            return
        }
        focusedField = firstField
    }
}
