import AgentCronCore
import SwiftUI

/// New Job, Open AgentCron…, and Quit.
struct PopoverFooter: View {
    let actions: PopoverActions

    var body: some View {
        HStack(alignment: .top) {
            Button(action: actions.newJob) {
                Label {
                    Text(PopoverText.newJob)
                } icon: {
                    Image(systemName: "plus")
                }
            }
            .accessibilityIdentifier("popoverNewJob")
            Spacer()
            VStack(alignment: .trailing, spacing: DesignLock.spacingXS) {
                Button(AppWindow.main.openCommandTitle, action: actions.openMainWindow)
                    .keyboardShortcut(",", modifiers: .command)
                    .accessibilityIdentifier("openMainWindowButton")
                Button(PopoverText.quit, action: actions.quit)
                    .keyboardShortcut("q", modifiers: .command)
                    .accessibilityIdentifier("popoverQuit")
            }
        }
    }
}
