import AgentCronCore
import Testing

@Suite("MenuBarPopover")
struct MenuBarPopoverTests {
    @Test
    func `the popover's placeholder reads in English`() {
        #expect(MenuBarPopover.placeholder
            .resolved(in: .english) == "Scheduled runs will appear here.")
    }
}
