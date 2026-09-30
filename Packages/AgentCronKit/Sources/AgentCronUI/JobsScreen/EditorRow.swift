import AgentCronCore
import SwiftUI

/// A validation error under a field: a glyph and red text, so color is not the only
/// carrier.
struct FieldMessage: View {
    let message: LocalizedStringResource

    var body: some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
        }
        .font(.footnote)
        .foregroundStyle(.red)
    }
}

/// One labeled row of the job editor, with the field's validation error below its
/// control (`docs/design/ux-guidelines.md` › Forms and validation).
struct EditorRow<Content: View>: View {
    let label: LocalizedStringResource
    let message: LocalizedStringResource?
    let identifier: String
    @ViewBuilder let content: Content

    var body: some View {
        LabeledContent {
            VStack(alignment: .leading, spacing: DesignLock.spacingXS) {
                content
                if let message {
                    FieldMessage(message: message)
                        .accessibilityIdentifier("\(identifier)Error")
                }
            }
        } label: {
            // The control carries the label, with any error, for VoiceOver; read here
            // too, it would be said twice.
            Text(label)
                .accessibilityHidden(true)
        }
    }
}
