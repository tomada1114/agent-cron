import AgentCronCore
import AgentCronPlatform
import AgentCronUI
import SwiftUI

/// The main window's default size from the design lock (ADR-0009). Its minimum size is
/// the root view's (`MainWindowView`), which `.contentMinSize` turns into the window's.
private enum MainWindowSize {
    static let defaultWidth: CGFloat = 1_040
    static let defaultHeight: CGFloat = 680
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
        .defaultSize(width: MainWindowSize.defaultWidth, height: MainWindowSize.defaultHeight)
        .windowResizability(.contentMinSize)
    }
}
