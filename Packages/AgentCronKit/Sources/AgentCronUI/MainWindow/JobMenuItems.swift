import AgentCronCore
import SwiftUI

/// The Job menu's items (`docs/product/ux-flows.md` §4), disabled while no saved job is
/// selected in the Jobs section: a menu item that cannot act is disabled, not hidden.
struct JobMenuItems: View {
    let navigation: MainNavigationModel

    var body: some View {
        Group {
            Button(MainMenuCommand.runNow.title) {
                navigation.runSelectedJobNow()
            }
            .keyboardShortcut("r", modifiers: .command)
            Button(MainMenuCommand.stop.title) {
                navigation.stopSelectedJob()
            }
            .keyboardShortcut(".", modifiers: .command)
            Button(MainMenuCommand.toggleEnabled.title) {
                navigation.toggleSelectedJobEnabled()
            }
            .keyboardShortcut("e", modifiers: .command)
            Divider()
            Button(MainMenuCommand.delete.title) {
                navigation.deleteSelectedJob()
            }
            .keyboardShortcut(.delete, modifiers: .command)
        }
        .disabled(!navigation.canActOnSelectedJob)
    }
}
