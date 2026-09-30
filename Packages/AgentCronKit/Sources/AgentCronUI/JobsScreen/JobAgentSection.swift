import AgentCronCore
import SwiftUI

/// The editor's Agent section: the agent, Model, Effort, Permission with the bypass
/// confirmation (`docs/product/ux-flows.md` S6), and Timeout.
struct JobAgentSection: View {
    private enum Layout {
        static let timeoutFieldWidth: CGFloat = 64
    }

    let editor: JobEditorModel
    let focus: FocusState<JobEditorField?>.Binding

    var body: some View {
        Section {
            LabeledContent {
                Text(editor.draft.agent.title)
            } label: {
                Text(JobsScreenText.agentLabel)
            }
            .accessibilityIdentifier("jobAgent")
            Picker(selection: Binding(
                get: { editor.draft.model },
                set: { editor.modelChosen($0) },
            )) {
                ForEach(ModelChoice.allCases, id: \.self) { choice in
                    Text(choice.title).tag(choice)
                }
            } label: {
                Text(JobsScreenText.modelLabel)
            }
            .accessibilityIdentifier("modelPicker")
            Picker(selection: Binding(
                get: { editor.draft.effort },
                set: { editor.effortChosen($0) },
            )) {
                ForEach(EffortChoice.allCases, id: \.self) { choice in
                    Text(choice.title).tag(choice)
                }
            } label: {
                Text(JobsScreenText.effortLabel)
            }
            .accessibilityIdentifier("effortPicker")
            permissionRow
            timeoutRow
        } header: {
            Text(JobsScreenText.agentSection)
                .font(.headline)
        }
        .alert(
            Text(JobsScreenText.bypassAlertTitle),
            isPresented: Binding(
                get: { editor.isConfirmingBypass },
                set: { _ in
                    // Only the alert's buttons answer it: each calls its own action.
                },
            ),
        ) {
            Button(role: .destructive) {
                editor.bypassConfirmed()
            } label: {
                Text(JobsScreenText.useBypass)
            }
            .accessibilityIdentifier("useBypassButton")
            Button(role: .cancel) {
                editor.bypassCancelled()
            } label: {
                Text(JobsScreenText.cancel)
            }
        } message: {
            Text(JobsScreenText.bypassAlertMessage)
        }
    }

    private var permissionRow: some View {
        VStack(alignment: .leading, spacing: DesignLock.spacingXS) {
            Picker(
                selection: Binding(
                    get: { editor.draft.permissionMode },
                    set: { editor.permissionModeChosen($0) },
                ),
            ) {
                ForEach(PermissionMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            } label: {
                Text(JobsScreenText.permissionLabel)
            }
            .accessibilityIdentifier("permissionPicker")
            if editor.usesBypassPermissions {
                Label {
                    Text(JobsScreenText.bypassNote)
                } icon: {
                    Image(systemName: OutcomeBadgeKind.bypass.symbolName)
                }
                .font(.footnote)
                .foregroundStyle(.red)
                .accessibilityIdentifier("bypassNote")
            }
        }
    }

    private var timeoutRow: some View {
        EditorRow(
            label: JobEditorField.timeout.title,
            message: editor.message(for: .timeout),
            identifier: "jobTimeout",
        ) {
            HStack(spacing: DesignLock.spacingS) {
                TextField(
                    value: Binding(
                        get: { editor.draft.timeoutMinutes },
                        set: { editor.timeoutChanged(to: $0) },
                    ),
                    format: .number.grouping(.never),
                ) {
                    // Hidden from sight; VoiceOver reads it, error included.
                    Text(editor.accessibilityLabel(for: .timeout))
                }
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: Layout.timeoutFieldWidth)
                .focused(focus, equals: .timeout)
                .accessibilityIdentifier("timeoutField")
                Text(JobsScreenText.timeoutUnit)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
