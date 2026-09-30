import AgentCronCore
import Foundation

extension LocalizationTests {
    /// Every resource the main window's navigation and menu commands return, once per key.
    static func navigationCases() -> [Case] {
        MainSection.allCases.flatMap { section in
            [
                Case(resource: section.title, arguments: []),
                Case(resource: section.placeholder, arguments: []),
            ]
        }
            + MainMenuCommand.allCases.map { Case(resource: $0.title, arguments: []) }
            + [Case(resource: MainMenuCommand.jobMenuTitle, arguments: [])]
    }
}
