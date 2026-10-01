import AgentCronCore
import AgentCronPlatform
import AgentCronUI
import SwiftUI

/// Application entry point — wiring only. All real code lives in Packages/AgentCronKit.
///
/// A menu-bar agent with one main window (ADR-0001): `LSUIElement` (`project.yml`) keeps
/// it out of the Dock and the app switcher, so the status item is the app's resident
/// surface. `.menuBarExtraStyle(.window)` renders the popover as a panel; the default
/// `.menu` style renders an NSMenu and accepts only menu-shaped content.
///
/// This is also the composition root: the one place that knows both halves of a port.
/// It constructs the `AgentCronPlatform` adapters and hands them to `AgentCronCore`'s
/// `AppEnvironment`, which owns every model and decides how they talk, so nothing below
/// `App/` — not a view model, not a view — depends on which implementation answers
/// (`docs/architecture.md` › Layers).
@main
struct AgentCronApp: App {
    /// Lives as long as the app: the scheduler runs, and the main menu's commands act on
    /// its navigation, whether or not any window is open.
    @State private var environment: AppEnvironment

    var body: some Scene {
        MenuBarExtra {
            PopoverView(
                model: environment.popover,
                navigation: environment.navigation,
                stop: { jobID in
                    environment.stopJob(jobID: jobID)
                },
                quit: quit,
            )
        } label: {
            AppStatusItemLabel(environment: environment)
        }
        .menuBarExtraStyle(.window)

        Window(Text(AppWindow.main.title), id: AppWindow.main.id) {
            AppMainWindow(environment: environment, quit: quit)
        }
        .defaultSize(
            width: DesignLock.mainWindowDefaultWidth,
            height: DesignLock.mainWindowDefaultHeight,
        )
        .windowResizability(.contentMinSize)
        .commands {
            MainWindowCommands(navigation: environment.navigation)
        }
    }

    /// Builds the real adapters and launches the app over them — before the first scene
    /// draws, so a notification click that launched the app finds its handler.
    init() {
        let built = AppEnvironment(ports: AppPorts(
            runner: ProcessAgentRunner(),
            systemEvents: WorkspaceSystemEvents(),
            sleepPreventer: PowerAssertionSleepPreventer(),
            notifier: UserNotificationPoster(),
            lifecycle: AppLifecyclePorts(
                loginItem: LoginItemController(),
                activationPolicy: ActivationPolicyController(),
            ),
        ))
        built.launch()
        _environment = State(initialValue: built)
    }

    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
