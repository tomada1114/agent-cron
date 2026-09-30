import AgentCronCore
import AgentCronPlatform
import AgentCronUI
import SwiftUI

/// Holds nothing until #28 hands the keep-awake controller the real IOKit preventer.
private struct UnwiredSleepPreventer: SleepPreventing {
    func hold(reason _: String) -> SleepPreventionToken {
        SleepPreventionToken(id: 0)
    }

    func release(_: SleepPreventionToken) {
        // Nothing was held.
    }
}

/// Application entry point — wiring only. All real code lives in Packages/AgentCronKit.
///
/// A menu-bar agent with one main window (ADR-0001): `LSUIElement` (`project.yml`) keeps
/// it out of the Dock and the app switcher, so the status item is the app's resident
/// surface. `.menuBarExtraStyle(.window)` renders the popover as a panel; the default
/// `.menu` style renders an NSMenu and accepts only menu-shaped content.
///
/// This is also the composition root: the one place that knows both halves of a port.
/// It constructs the `AgentCronPlatform` adapter and hands it to a `AgentCronCore` view model,
/// so nothing below `App/` — not the view model, not the view — depends on which
/// implementation answers (`docs/architecture.md` › Layers).
@main
struct AgentCronApp: App {
    /// Lives as long as the app: the main menu's commands act on it while the main
    /// window is closed too.
    @State private var navigation = MainNavigationModel()

    /// Reads the saved jobs and runs; the running set, agent availability, and a real
    /// sleep preventer arrive with the Dispatcher wiring (#28).
    @State private var popover = PopoverModel(
        jobStore: FileJobStore(root: StorageLocation.root()),
        runStore: FileRunStore(root: StorageLocation.root()),
        keepAwake: KeepAwakeController(preventer: UnwiredSleepPreventer()),
        calendar: .current,
    )

    var body: some Scene {
        MenuBarExtra {
            PopoverView(
                model: popover,
                navigation: navigation,
                stop: { _ in
                    // Stopping a run is wired to the Dispatcher in #28.
                },
                quit: {
                    NSApplication.shared.terminate(nil)
                },
            )
        } label: {
            StatusItemLabel(model: popover)
        }
        .menuBarExtraStyle(.window)

        Window(Text(AppWindow.main.title), id: AppWindow.main.id) {
            MainWindowView(navigation: navigation)
        }
        .defaultSize(
            width: DesignLock.mainWindowDefaultWidth,
            height: DesignLock.mainWindowDefaultHeight,
        )
        .windowResizability(.contentMinSize)
        .commands {
            MainWindowCommands(navigation: navigation)
        }
    }
}
