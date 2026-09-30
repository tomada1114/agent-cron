import AgentCronCore
import SwiftUI

/// One job in the list: its enabled dot, name, bypass badge, schedule, and status
/// (`docs/product/ux-flows.md` S2).
struct JobListRowView: View {
    let row: JobListRow
    let status: LocalizedStringResource

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignLock.spacingS) {
            // The dot repeats what the status line says in words ("Paused").
            Image(systemName: row.isEnabled ? "circle.fill" : "circle")
                .font(.caption2)
                .foregroundStyle(row.isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignLock.spacingXS) {
                HStack(spacing: DesignLock.spacingS) {
                    Text(verbatim: row.name)
                        .lineLimit(1)
                    if row.usesBypassPermissions {
                        OutcomeBadge(kind: .bypass)
                            .font(.caption)
                    }
                }
                if let summary = row.scheduleSummary {
                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                if row.isRunning {
                    OutcomeBadge(kind: .running)
                        .font(.callout)
                } else {
                    Text(status)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, DesignLock.spacingXS)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("jobRow")
    }
}
