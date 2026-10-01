import AgentCronCore
import SwiftUI

/// The main window's content as the app runs it: ``MainWindowView`` over the models
/// ``AgentCronCore/AppEnvironment`` owns, the unreadable-jobs alert, and the reports that
/// the window opened and closed (ADR-0001: a Dock icon and main menu only while it is
/// open).
///
/// It decides nothing; `App/` builds it once in the `Window` scene.
public struct AppMainWindow: View {
    private let environment: AppEnvironment
    private let quit: () -> Void

    public var body: some View {
        MainWindowView(
            navigation: environment.navigation,
            jobList: environment.jobList,
            notifications: environment.notifications,
            history: environment.history,
            stopRun: { runID in
                environment.stop(runID: runID)
            },
            general: environment.general,
        )
        .launchErrorAlert(environment.launchError, tryAgain: environment.tryAgain, quit: quit)
        .onAppear(perform: environment.mainWindowOpened)
        .onDisappear(perform: environment.mainWindowClosed)
    }

    /// Creates the window's content.
    /// - Parameter quit: Quits the app, from the unreadable-jobs alert.
    public init(environment: AppEnvironment, quit: @escaping () -> Void) {
        self.environment = environment
        self.quit = quit
    }
}
