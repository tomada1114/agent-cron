import AgentCronCore
import SwiftUI

/// The status item's popover — a placeholder until the run timeline, keep-awake control,
/// and the rest of its commands replace it (`docs/product/ux-flows.md` S1). It already
/// carries the one command the app shape needs to be usable: opening the main window.
///
/// The app's name in the heading is a proper noun, not language, so it is verbatim;
/// every other word comes from Core, because a `Text("…")` literal here would be looked
/// up in the app's main bundle, not the package's catalog.
public struct ContentView: View {
    /// Present only when the app shell handed one down — the view has no way to build a
    /// ``FrontmostAppViewModel``, because the port's adapter lives in `AgentCronPlatform`,
    /// which `AgentCronUI` must not import. Previews and tests simply leave it out.
    @State private var frontmostApp: FrontmostAppViewModel?
    @Environment(\.scenePhase)
    private var scenePhase
    @Environment(\.openWindow)
    private var openWindow

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignLock.spacingS) {
            Text(verbatim: "AgentCron")
                .font(.headline)
            Text(MenuBarPopover.placeholder)
                .foregroundStyle(.secondary)
            Button(AppWindow.main.openCommandTitle) {
                openWindow(id: AppWindow.main.id)
            }
            .keyboardShortcut(",", modifiers: .command)
            .accessibilityIdentifier("openMainWindowButton")
            if let frontmostApp {
                Text(frontmostApp.label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("frontmostAppLabel")
            }
        }
        .padding(DesignLock.popoverPadding)
        .frame(width: DesignLock.popoverWidth, alignment: .leading)
        // The port answers with a snapshot, so the snapshot is retaken every time this
        // scene becomes active — reading it once at launch would pin the label to
        // whoever launched the app. `initial: true` covers the case where the scene is
        // already active on first render.
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else {
                return
            }
            frontmostApp?.refresh()
        }
    }

    /// Creates the popover's content.
    ///
    /// `frontmostApp` is the worked example of a Core view model over an OS port: the
    /// app shell builds it with a `AgentCronPlatform` adapter and hands it down, so this
    /// view renders the answer without knowing where it came from.
    public init(frontmostApp: FrontmostAppViewModel? = nil) {
        _frontmostApp = State(initialValue: frontmostApp)
    }
}

#Preview("Default") {
    ContentView()
}
