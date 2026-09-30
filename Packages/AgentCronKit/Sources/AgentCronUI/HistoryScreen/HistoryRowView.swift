import AgentCronCore
import SwiftUI

/// One run: its outcome glyph, start time, job, duration, and cost.
struct HistoryRowView: View {
    let row: HistoryRow

    var body: some View {
        HStack(spacing: DesignLock.spacingS) {
            OutcomeBadge(kind: row.badge)
                .labelStyle(.iconOnly)
            Text(verbatim: row.timeText)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(row.jobTitle)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: DesignLock.spacingS)
            if let duration = row.duration {
                Text(duration)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if let cost = row.cost {
                Text(verbatim: cost)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("historyRow")
    }
}
