import AgentCronCore
import SwiftUI

/// The alert shown while the saved jobs cannot be read at launch
/// (`docs/design/ux-guidelines.md` › Feedback and loading): the reason, [Quit], and
/// [Try Again]. What each button does is the caller's; the wording is Core's.
struct LaunchErrorAlert: ViewModifier {
    let error: StorageError?
    let tryAgain: () -> Void
    let quit: () -> Void

    func body(content: Content) -> some View {
        content.alert(
            Text(LaunchErrorText.title),
            isPresented: Binding(get: { error != nil }, set: { _ in
                // Only the alert's buttons answer it: each calls its own action.
            }),
            presenting: error,
        ) { _ in
            Button(action: quit) {
                Text(LaunchErrorText.quit)
            }
            .accessibilityIdentifier("launchErrorQuitButton")
            Button(action: tryAgain) {
                Text(LaunchErrorText.tryAgain)
            }
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("launchErrorTryAgainButton")
        } message: { error in
            Text(LaunchErrorText.message(for: error))
        }
    }
}

extension View {
    /// Shows the unreadable-jobs alert while `error` is not `nil`.
    func launchErrorAlert(
        _ error: StorageError?,
        tryAgain: @escaping () -> Void,
        quit: @escaping () -> Void,
    ) -> some View {
        modifier(LaunchErrorAlert(error: error, tryAgain: tryAgain, quit: quit))
    }
}

#Preview("Corrupt jobs") {
    MainWindowView(navigation: .preview(showing: .jobs))
        .launchErrorAlert(
            .corruptJobs,
            tryAgain: {
                // A preview reads nothing again.
            },
            quit: {
                // A preview quits nothing.
            },
        )
}

#Preview("Newer version") {
    MainWindowView(navigation: .preview(showing: .jobs))
        .launchErrorAlert(
            .newerJobsVersion(schemaVersion: 2),
            tryAgain: {
                // A preview reads nothing again.
            },
            quit: {
                // A preview quits nothing.
            },
        )
}
