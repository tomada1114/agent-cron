import AgentCronCore
import SwiftUI

/// The run's §3.4 fields as label–value rows; a field the run lacks is left out.
struct HistoryRunFields: View {
    let detail: HistoryRunDetail

    var body: some View {
        Grid(
            alignment: .leadingFirstTextBaseline,
            horizontalSpacing: DesignLock.spacingM,
            verticalSpacing: DesignLock.spacingXS,
        ) {
            timingRows
            agentRows
        }
        .textSelection(.enabled)
    }

    @ViewBuilder private var timingRows: some View {
        field(HistoryScreenText.trigger) { Text(detail.trigger) }
        if let scheduled = detail.scheduledText {
            field(HistoryScreenText.scheduled) { Text(verbatim: scheduled) }
        }
        field(HistoryScreenText.started) { Text(verbatim: detail.startedText) }
        if let duration = detail.duration {
            field(HistoryScreenText.duration) { Text(duration) }
        } else if detail.body == .running {
            field(HistoryScreenText.elapsed) {
                TimelineView(.periodic(from: detail.run.startedAt, by: 1)) { context in
                    Text(verbatim: HistoryFormatting.elapsed(
                        from: detail.run.startedAt,
                        to: context.date,
                    ))
                    .monospacedDigit()
                }
                .accessibilityIdentifier("historyElapsed")
            }
        }
        if let cost = detail.cost {
            field(HistoryScreenText.cost) { Text(verbatim: cost) }
        }
        if let exitCode = detail.run.exitCode {
            field(HistoryScreenText.exitCode) { Text(verbatim: String(exitCode)) }
        }
    }

    @ViewBuilder private var agentRows: some View {
        field(HistoryScreenText.directory) {
            Text(verbatim: detail.run.snapshot.directory.path(percentEncoded: false))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        field(HistoryScreenText.model) { Text(detail.run.snapshot.model.title) }
        field(HistoryScreenText.effort) { Text(detail.run.snapshot.effort.title) }
        field(HistoryScreenText.permission) { Text(detail.run.snapshot.permissionMode.title) }
        if let session = detail.run.sessionID {
            field(HistoryScreenText.session) {
                Text(verbatim: session)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private func field(
        _ label: LocalizedStringResource,
        @ViewBuilder value: () -> some View,
    ) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            value()
        }
        .accessibilityElement(children: .combine)
    }
}
