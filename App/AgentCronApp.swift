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
/// It constructs the `AgentCronPlatform` adapter and hands it to a `AgentCronCore` view model,
/// so nothing below `App/` — not the view model, not the view — depends on which
/// implementation answers (`docs/architecture.md` › Layers).
@main
struct AgentCronApp: App {
    var body: some Scene {
        MenuBarExtra("AgentCron", systemImage: "clock") {
            ContentView(
                frontmostApp: FrontmostAppViewModel(provider: WorkspaceFrontmostAppProvider()),
            )
        }
        .menuBarExtraStyle(.window)

        Window(Text(AppWindow.main.title), id: AppWindow.main.id) {
            MainWindowView()
        }
        .defaultSize(
            width: DesignLock.mainWindowDefaultWidth,
            height: DesignLock.mainWindowDefaultHeight,
        )
        .windowResizability(.contentMinSize)
    }
}
