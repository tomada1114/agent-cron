import AgentCronCore
import SwiftUI

/// The status item's label as the app runs it: ``StatusItemLabel`` over the popover's
/// model, and the one view alive from launch to quit — so it is what opens the main
/// window when ``AgentCronCore/AppEnvironment`` asks for it (a notification click, or jobs
/// that cannot be read at launch), since only a view can.
public struct AppStatusItemLabel: View {
    private let environment: AppEnvironment

    @Environment(\.openWindow)
    private var openWindow

    public var body: some View {
        StatusItemLabel(model: environment.popover)
            .onAppear(perform: openMainWindowIfRequested)
            .onChange(of: environment.isMainWindowRequested) {
                openMainWindowIfRequested()
            }
    }

    /// Creates the label.
    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    private func openMainWindowIfRequested() {
        guard environment.isMainWindowRequested else {
            return
        }
        openWindow(id: AppWindow.main.id)
        environment.mainWindowRequestHandled()
    }
}
