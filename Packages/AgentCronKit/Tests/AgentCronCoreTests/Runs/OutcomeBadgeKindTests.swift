import AgentCronCore
import Testing

@Suite("OutcomeBadgeKind")
struct OutcomeBadgeKindTests {
    @Test(arguments: [
        (RunOutcome.failed, OutcomeBadgeKind.failed),
        (.running, .running),
        (.skipped, .skipped),
        (.stopped, .stopped),
        (.succeeded, .succeeded),
        (.timedOut, .timedOut),
    ])
    func `every run outcome maps to its own badge`(outcome: RunOutcome, kind: OutcomeBadgeKind) {
        #expect(OutcomeBadgeKind(outcome) == kind)
    }

    @Test
    func `the glyphs are the design lock's`() {
        let symbols = Dictionary(uniqueKeysWithValues: OutcomeBadgeKind.allCases.map { kind in
            (kind, kind.symbolName)
        })
        #expect(symbols == [
            .succeeded: "checkmark.circle.fill",
            .failed: "xmark.circle.fill",
            .timedOut: "timer",
            .stopped: "stop.circle",
            .skipped: "arrow.uturn.right.circle",
            .running: "circle.dotted",
            .upcoming: "circle",
            .bypass: "exclamationmark.triangle.fill",
        ])
    }

    @Test
    func `the labels read in English`() {
        let labels = Dictionary(uniqueKeysWithValues: OutcomeBadgeKind.allCases.map { kind in
            (kind, kind.label.resolved(in: .english))
        })
        #expect(labels == [
            .succeeded: "Succeeded",
            .failed: "Failed",
            .timedOut: "Timed Out",
            .stopped: "Stopped",
            .skipped: "Skipped",
            .running: "Running",
            .upcoming: "Upcoming",
            .bypass: "Bypass",
        ])
    }
}
