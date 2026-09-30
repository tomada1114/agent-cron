import AgentCronCore
import Foundation
import SwiftUI

// Previews of the General screen, one per state the issue names (#25): available, not
// found, checking, requires approval. Each builds its model over in-memory ports.

/// A login item for previews that holds its status in memory.
private final class PreviewLoginItem: LoginItemControlling {
    let status: LoginItemStatus

    init(status: LoginItemStatus) {
        self.status = status
    }

    func register() {
        // A preview changes nothing.
    }

    func unregister() {
        // A preview changes nothing.
    }

    func openLoginItemsSettings() {
        // A preview opens nothing.
    }
}

/// A runner for previews: `claude` resolves to a fixed path, is missing, or never answers.
private struct PreviewRunner: AgentRunning {
    enum Answer {
        case available
        case notFound
        case never
    }

    static let path = "/Users/me/.local/bin/claude"
    private static let secondsInAnHour = 3_600

    let answer: Answer

    func run(argv: [String], directory _: URL, timeout _: Duration) async -> ProcessOutcome {
        switch answer {
        case .never:
            try? await Task.sleep(for: .seconds(Self.secondsInAnHour))
            return ProcessOutcome(stdout: Data(), stderr: "", exitCode: 1, terminatedBy: .stopped)

        case .notFound:
            return ProcessOutcome(stdout: Data(), stderr: "", exitCode: 1, terminatedBy: .exit)

        case .available:
            let stdout = argv.last == "--version" ? "2.1.3 (Claude Code)\n" : "\(Self.path)\n"
            return ProcessOutcome(
                stdout: Data(stdout.utf8),
                stderr: "",
                exitCode: 0,
                terminatedBy: .exit,
            )
        }
    }
}

@MainActor
private enum GeneralPreview {
    static func model(
        _ answer: PreviewRunner.Answer,
        loginItem: LoginItemStatus = .enabled,
    ) -> GeneralModel {
        GeneralModel(
            loginItem: PreviewLoginItem(status: loginItem),
            checker: AgentAvailabilityChecker(runner: PreviewRunner(answer: answer)),
        )
    }
}

#Preview("Available") {
    GeneralScreenView(model: GeneralPreview.model(.available))
}

#Preview("Not found") {
    GeneralScreenView(model: GeneralPreview.model(.notFound))
}

#Preview("Checking") {
    GeneralScreenView(model: GeneralPreview.model(.never))
}

#Preview("Requires approval") {
    GeneralScreenView(model: GeneralPreview.model(.available, loginItem: .requiresApproval))
}

#Preview("Dark") {
    GeneralScreenView(model: GeneralPreview.model(.available))
        .preferredColorScheme(.dark)
}
