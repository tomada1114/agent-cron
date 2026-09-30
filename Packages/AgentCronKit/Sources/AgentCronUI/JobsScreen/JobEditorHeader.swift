import AgentCronCore
import SwiftUI

/// The editor's header: the job's name, its status, the running note, the Enabled
/// switch, and Edited / Revert / Save (`docs/design/ux-guidelines.md` › Feedback and
/// loading).
struct JobEditorHeader: View {
    let editor: JobEditorModel
    let status: LocalizedStringResource?
    let save: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignLock.spacingM) {
            VStack(alignment: .leading, spacing: DesignLock.spacingXS) {
                title
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .accessibilityIdentifier("jobEditorTitle")
                statusLine
                if let note = editor.runningNote {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("jobRunningNote")
                }
                if editor.storageError != nil {
                    Label {
                        Text(JobsScreenText.saveFailed)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("jobSaveFailed")
                }
            }
            Spacer(minLength: DesignLock.spacingS)
            // The buttons keep their full width; the name truncates instead.
            controls
                .fixedSize()
                .layoutPriority(1)
        }
    }

    @ViewBuilder private var title: some View {
        if let name = editor.headerName {
            Text(verbatim: name)
        } else {
            Text(MainMenuCommand.newJob.title)
        }
    }

    @ViewBuilder private var statusLine: some View {
        if editor.isRunning {
            OutcomeBadge(kind: .running)
                .font(.callout)
        } else if let status {
            Text(status)
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .accessibilityIdentifier("jobStatus")
        }
    }

    private var controls: some View {
        HStack(spacing: DesignLock.spacingS) {
            if editor.isEdited {
                Text(JobsScreenText.edited)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("jobEditedLabel")
            }
            Button {
                editor.revert()
            } label: {
                Text(JobsScreenText.revert)
            }
            .disabled(!editor.isEdited)
            .accessibilityIdentifier("revertButton")
            Button(action: save) {
                Text(JobsScreenText.save)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!editor.canSave)
            .accessibilityIdentifier("saveButton")
            enabledSwitch
        }
    }

    /// The switch alone, as in ux-flows S2's header; its label is what VoiceOver and the
    /// tooltip say.
    private var enabledSwitch: some View {
        Toggle(
            isOn: Binding(
                get: { editor.draft.enabled },
                set: { editor.enabledChanged(to: $0) },
            ),
        ) {
            Text(JobsScreenText.enabledLabel)
        }
        .toggleStyle(.switch)
        .labelsHidden()
        .help(Text(JobsScreenText.enabledLabel))
        .accessibilityIdentifier("enabledToggle")
    }
}
