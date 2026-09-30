import AgentCronCore
import Testing

/// The sidebar's sections and the menu commands' words (`docs/product/ux-flows.md` S2–S4
/// and §4).
@Suite("Main sections and menu commands")
struct MainSectionTests {
    @Test
    func `the sidebar lists Jobs, History, and General in that order`() {
        #expect(MainSection.allCases == [.jobs, .history, .general])
    }

    @Test(arguments: [
        (MainSection.jobs, "Jobs", "Your jobs will appear here."),
        (.history, "History", "Runs will appear here after a job runs."),
        (.general, "General", "Settings will appear here."),
    ])
    func `each section's words read in English`(
        section: MainSection,
        title: String,
        placeholder: String,
    ) {
        #expect(section.title.resolved(in: .english) == title)
        #expect(section.placeholder.resolved(in: .english) == placeholder)
        #expect(section.id == section)
    }

    @Test(arguments: [
        (MainMenuCommand.settings, "Settings…"),
        (.newJob, "New Job"),
        (.runNow, "Run Now"),
        (.stop, "Stop"),
        (.toggleEnabled, "Enable / Disable"),
        (.delete, "Delete…"),
    ])
    func `each menu command's title reads in English`(command: MainMenuCommand, title: String) {
        #expect(command.title.resolved(in: .english) == title)
    }

    @Test
    func `the Job menu's title reads in English`() {
        #expect(MainMenuCommand.jobMenuTitle.resolved(in: .english) == "Job")
    }
}
