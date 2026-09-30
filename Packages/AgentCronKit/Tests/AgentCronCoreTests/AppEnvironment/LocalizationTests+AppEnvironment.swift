import AgentCronCore
import Foundation

extension LocalizationTests {
    private static let newerSchemaVersion = 2
    private static let refusedReadCode = 257

    /// Every resource the unreadable-jobs alert shows, once per key.
    static func appEnvironmentCases() -> [Case] {
        [
            Case(resource: LaunchErrorText.title, arguments: []),
            Case(resource: LaunchErrorText.quit, arguments: []),
            Case(resource: LaunchErrorText.tryAgain, arguments: []),
            Case(resource: LaunchErrorText.message(for: .corruptJobs), arguments: []),
            Case(
                resource: LaunchErrorText
                    .message(for: .newerJobsVersion(schemaVersion: newerSchemaVersion)),
                arguments: [],
            ),
            Case(
                resource: LaunchErrorText.message(for: .readFailed(code: refusedReadCode)),
                arguments: [refusedReadCode],
            ),
        ]
    }
}
