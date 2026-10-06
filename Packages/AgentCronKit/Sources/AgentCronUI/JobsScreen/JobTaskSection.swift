import AgentCronCore
import SwiftUI
import UniformTypeIdentifiers

/// The editor's Task section: Name, Directory, and Prompt.
struct JobTaskSection: View {
    private enum Layout {
        static let promptMinHeight: CGFloat = 96
    }

    let editor: JobEditorModel
    let focus: FocusState<JobEditorField?>.Binding

    @State private var isChoosingFolder = false

    var body: some View {
        Section {
            nameRow
            directoryRow
            promptRow
        } header: {
            Text(JobsScreenText.taskSection)
                .font(.headline)
        }
    }

    private var nameRow: some View {
        EditorRow(
            label: JobEditorField.name.title,
            message: editor.message(for: .name),
            identifier: "jobName",
        ) {
            TextField(
                text: Binding(get: { editor.draft.name }, set: { editor.nameChanged(to: $0) }),
            ) {
                // Hidden from sight (the row shows the label); VoiceOver reads it, error
                // included.
                Text(editor.accessibilityLabel(for: .name))
            }
            .labelsHidden()
            .focused(focus, equals: .name)
            .accessibilityIdentifier("jobNameField")
        }
    }

    private var directoryRow: some View {
        EditorRow(
            label: JobEditorField.directory.title,
            message: editor.message(for: .directory),
            identifier: "jobDirectory",
        ) {
            HStack(spacing: DesignLock.spacingS) {
                directoryText
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    // A label set straight on a `Text` recursed inside AppKit's AX bridge
                    // and crashed (#76); a container element owns the label instead.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(editor.accessibilityLabel(for: .directory)))
                    .accessibilityValue(directoryValue)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityIdentifier("jobDirectoryPath")
                Spacer(minLength: DesignLock.spacingS)
                Button {
                    isChoosingFolder = true
                } label: {
                    Text(JobsScreenText.chooseFolder)
                }
                .focused(focus, equals: .directory)
                .accessibilityIdentifier("chooseFolderButton")
            }
            if let note = editor.directoryMissingNote {
                Label {
                    Text(note)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.footnote)
                .foregroundStyle(.orange)
                .accessibilityIdentifier("jobDirectoryMissing")
            }
        }
        .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
            switch result {
            case let .success(url):
                editor.directoryChosen(url)

            case let .failure(error):
                editor.directoryChoiceFailed(error)
            }
        }
    }

    /// What the ignored `Text` would have read: the path, or that none is chosen.
    private var directoryValue: Text {
        if let path = editor.directoryPath {
            Text(verbatim: path)
        } else {
            Text(JobsScreenText.noFolderChosen)
        }
    }

    @ViewBuilder private var directoryText: some View {
        if let path = editor.directoryPath {
            Text(verbatim: path)
        } else {
            Text(JobsScreenText.noFolderChosen)
                .foregroundStyle(.secondary)
        }
    }

    /// The prompt runs the pane's full width under its label, since it is the one field
    /// long enough to need it.
    private var promptRow: some View {
        VStack(alignment: .leading, spacing: DesignLock.spacingS) {
            Text(JobEditorField.prompt.title)
                .accessibilityHidden(true)
            TextEditor(
                text: Binding(get: { editor.draft.prompt }, set: { editor.promptChanged(to: $0) }),
            )
            .font(.body.monospaced())
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: Layout.promptMinHeight)
            .overlay {
                RoundedRectangle(cornerRadius: DesignLock.chipCornerRadius)
                    .strokeBorder(.separator)
            }
            .focused(focus, equals: .prompt)
            .accessibilityLabel(Text(editor.accessibilityLabel(for: .prompt)))
            .accessibilityIdentifier("jobPromptEditor")
            if let message = editor.message(for: .prompt) {
                FieldMessage(message: message)
                    .accessibilityIdentifier("jobPromptError")
            }
        }
    }
}
