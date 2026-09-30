import AgentCronCore
import Foundation

extension LocalizationTests {
    /// Every resource the General screen returns, once per key.
    static func generalScreenCases() -> [Case] {
        [
            GeneralScreenText.startupHeading,
            GeneralScreenText.launchAtLogin,
            GeneralScreenText.openLoginItems,
            GeneralScreenText.loginItemRequiresApproval,
            GeneralScreenText.loginItemNotFound,
            GeneralScreenText.agentsHeading,
            GeneralScreenText.claudeCode,
            GeneralScreenText.resolvedViaLoginShell,
            GeneralScreenText.notFound,
            GeneralScreenText.notFoundHint,
            GeneralScreenText.checkAgain,
            GeneralScreenText.checking,
            GeneralScreenText.keepAwakeHeading,
            GeneralScreenText.keepAwakeWhileRunning,
            GeneralScreenText.keepAwakeAlwaysOn,
            GeneralScreenText.historyHeading,
            GeneralScreenText.retention,
        ].map { Case(resource: $0, arguments: []) } + [
            Case(
                resource: GeneralModel.agentHeadline(for: .error("timed out")) ??
                    GeneralScreenText.notFound,
                arguments: ["timed out"],
            ),
        ]
    }
}
