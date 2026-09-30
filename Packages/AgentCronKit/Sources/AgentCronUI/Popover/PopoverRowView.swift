import AgentCronCore
import SwiftUI

/// One timeline row: time, outcome badge, job name, then a finished run's duration and
/// cost, a running run's elapsed time and Stop, or the bypass flag.
struct PopoverRowView: View {
    private static let stopSize: CGFloat = 24

    let row: PopoverRow
    let actions: PopoverActions

    @Environment(\.locale)
    private var locale

    var body: some View {
        if let runID = finishedRunID {
            Button {
                actions.openRun(runID)
            } label: {
                content
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("popoverRow.\(row.id)")
        } else {
            content
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("popoverRow.\(row.id)")
        }
    }

    /// A finished run's identifier; running and upcoming rows open nothing.
    private var finishedRunID: UUID? {
        switch row.badge {
        case .running, .upcoming, .bypass:
            nil

        default:
            UUID(uuidString: row.id)
        }
    }

    private var content: some View {
        HStack(spacing: DesignLock.spacingS) {
            Text(verbatim: row.timeText)
                .monospacedDigit()
            OutcomeBadge(kind: row.badge)
                .labelStyle(.iconOnly)
            Text(verbatim: row.jobName)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: DesignLock.spacingXS)
            trailing
        }
        .frame(minHeight: DesignLock.popoverRowHeight)
    }

    @ViewBuilder private var trailing: some View {
        if row.badge == .running {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(verbatim: PopoverText.elapsed(since: row.date, now: context.date))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Button {
                actions.stop(row.jobID)
            } label: {
                Image(systemName: "stop.fill")
                    .frame(width: Self.stopSize, height: Self.stopSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text(PopoverText.stop(jobName: row.jobName)))
            .accessibilityIdentifier("popoverStop.\(row.id)")
        } else {
            if row.usesBypassPermissions {
                OutcomeBadge(kind: .bypass)
                    .font(.caption)
            }
            if let duration = row.duration {
                Text(verbatim: PopoverText.duration(duration, locale: locale))
                    .foregroundStyle(.secondary)
            }
            if let cost = row.costUSD {
                Text(verbatim: PopoverText.cost(cost, locale: locale))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
