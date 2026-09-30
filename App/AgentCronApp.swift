import AgentCronCore
import AgentCronPlatform
import AgentCronUI
import SwiftUI

/// Application entry point — wiring only. All real code lives in Packages/AgentCronKit.
///
/// This is also the composition root: the one place that knows both halves of a port.
/// It constructs the `AgentCronPlatform` adapter and hands it to a `AgentCronCore` view model,
/// so nothing below `App/` — not the view model, not the view — depends on which
/// implementation answers (`docs/architecture.md` › Layers).
@main
struct AgentCronApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(
                frontmostApp: FrontmostAppViewModel(provider: WorkspaceFrontmostAppProvider()),
            )
        }
    }
}
