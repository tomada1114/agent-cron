import AgentCronCore
import Testing

@Suite("AppWindow")
struct AppWindowTests {
    @Test
    func `the main window's scene identifier is main`() {
        #expect(AppWindow.main.id == "main")
    }

    @Test
    func `every window has its own scene identifier`() {
        let ids = AppWindow.allCases.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test
    func `the main window's words read in English`() {
        #expect(AppWindow.main.title.resolved(in: .english) == "AgentCron")
        #expect(AppWindow.main.openCommandTitle.resolved(in: .english) == "Open AgentCron…")
    }
}
