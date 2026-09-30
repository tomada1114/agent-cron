import AgentCronCore
import SwiftUI

/// The main menu's app-specific commands with their shortcuts (`docs/product/ux-flows.md`
/// §4): Settings… ⌘, in the app menu, New Job ⌘N in File, the Job menu, and the sections
/// and Toggle Sidebar ⌃⌘S in View. Quit ⌘Q and Close ⌘W are the system's own items.
///
/// Every command calls a ``MainNavigationModel`` action; a command that lands in the main
/// window also opens it, since the menu can be used while it is closed. The main menu is
/// shown only while the app is a regular app, which ADR-0001 makes true while the main
/// window is open.
public struct MainWindowCommands: Commands {
    private let navigation: MainNavigationModel
    @Environment(\.openWindow)
    private var openWindow

    public var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(MainMenuCommand.settings.title) {
                navigation.openSettings()
                openMainWindow()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        CommandGroup(replacing: .newItem) {
            Button(MainMenuCommand.newJob.title) {
                navigation.newJob()
                openMainWindow()
            }
            .keyboardShortcut("n", modifiers: .command)
        }
        CommandMenu(Text(MainMenuCommand.jobMenuTitle)) {
            JobMenuItems(navigation: navigation)
        }
        SidebarCommands()
        CommandGroup(before: .sidebar) {
            ForEach(MainSection.allCases) { section in
                Button(section.title) {
                    navigation.select(section: section)
                    openMainWindow()
                }
                .keyboardShortcut(section.shortcutKey, modifiers: .command)
            }
            Divider()
        }
    }

    /// Creates the commands over the same `navigation` the main window renders.
    public init(navigation: MainNavigationModel) {
        self.navigation = navigation
    }

    private func openMainWindow() {
        openWindow(id: AppWindow.main.id)
    }
}

extension MainSection {
    /// The digit that, with ⌘, selects the section: its position in the sidebar.
    var shortcutKey: KeyEquivalent {
        switch self {
        case .jobs:
            "1"

        case .history:
            "2"

        case .general:
            "3"
        }
    }
}
