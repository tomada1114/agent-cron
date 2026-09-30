import AgentCronCore
import SwiftUI

/// One run's detail (`docs/product/ux-flows.md` S3; requirements §3.4): a header with the
/// outcome and Open Job, the run's fields, then its result, skip reason, or running
/// state, and the prompt it used, collapsed.
struct HistoryRunDetailView: View {
    let detail: HistoryRunDetail
    let openJob: () -> Void
    /// Stops the run; `nil` while no runner is wired in, which leaves Stop disabled.
    let stop: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignLock.spacingM) {
                header
                HistoryRunFields(detail: detail)
                Divider()
                HistoryRunBodyView(detail: detail, stop: stop)
                DisclosureGroup {
                    Text(verbatim: detail.run.snapshot.prompt)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Text(HistoryScreenText.prompt)
                        .font(.headline)
                }
                .accessibilityIdentifier("historyPrompt")
            }
            .padding(DesignLock.spacingL)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("historyDetail")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignLock.spacingS) {
            VStack(alignment: .leading, spacing: DesignLock.spacingXS) {
                Text(detail.jobTitle)
                    .font(.title2)
                    .textSelection(.enabled)
                HStack(spacing: DesignLock.spacingS) {
                    OutcomeBadge(kind: detail.badge)
                    Text(verbatim: "·")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(detail.trigger)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if detail.canOpenJob {
                Button(action: openJob) {
                    Text(HistoryScreenText.openJob)
                }
                .buttonStyle(.link)
                .accessibilityIdentifier("historyOpenJobButton")
            }
        }
    }
}
