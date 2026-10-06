import AgentCronCore
import SwiftUI

/// The status item's popover (`docs/product/ux-flows.md` S1): the banners, today's
/// timeline, the keep-awake menu, and the footer, rendered from ``PopoverModel``.
///
/// Opening the main window on a section or run is navigation this view does itself;
/// stopping a run and quitting are the app shell's, passed in as `stop` and `quit`.
/// The model is loaded when the popover shows and marked seen when it closes, so the
/// failure banner stays up while the user reads it.
public struct PopoverView: View {
    private let model: PopoverModel
    private let navigation: MainNavigationModel
    private let stop: (UUID) -> Void
    private let quit: () -> Void

    @Environment(\.openWindow)
    private var openWindow

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PopoverBanners(model: model, actions: actions)
            PopoverTimeline(model: model, actions: actions)
            Divider()
            PopoverKeepAwakeRow(model: model)
                .padding(DesignLock.popoverPadding)
            Divider()
            PopoverFooter(actions: actions)
                .padding(DesignLock.popoverPadding)
        }
        .frame(width: DesignLock.popoverWidth)
        .frame(maxHeight: DesignLock.popoverMaxHeight)
        // The timeline's ScrollView is greedy; without this the window keeps a cleared
        // banner's height as a blank band. Ideal height is clamped by the frame above.
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("popover")
        .onAppear {
            model.load()
        }
        .onDisappear {
            model.open()
        }
    }

    private var actions: PopoverActions {
        PopoverActions(
            openRun: { runID in
                navigation.select(section: .history)
                navigation.select(runID: runID)
                openMainWindow()
            },
            open: { section in
                navigation.select(section: section)
                openMainWindow()
            },
            newJob: {
                navigation.newJob()
                openMainWindow()
            },
            openMainWindow: openMainWindow,
            stop: stop,
            quit: quit,
        )
    }

    /// Creates the popover.
    /// - Parameters:
    ///   - stop: Stops the running run of the job with this identifier, without asking.
    ///   - quit: Quits the app.
    public init(
        model: PopoverModel,
        navigation: MainNavigationModel,
        stop: @escaping (UUID) -> Void,
        quit: @escaping () -> Void,
    ) {
        self.model = model
        self.navigation = navigation
        self.stop = stop
        self.quit = quit
    }

    private func openMainWindow() {
        openWindow(id: AppWindow.main.id)
    }
}
