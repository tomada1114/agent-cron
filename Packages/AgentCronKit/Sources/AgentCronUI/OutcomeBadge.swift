import AgentCronCore
import SwiftUI

/// A status badge: the design lock's glyph and color beside a text label (ADR-0009), so
/// color is never the only carrier. Outcome colors are fixed and ignore the user's
/// accent setting.
public struct OutcomeBadge: View {
    private let kind: OutcomeBadgeKind

    public var body: some View {
        Label {
            Text(kind.label)
        } icon: {
            Image(systemName: kind.symbolName)
                .foregroundStyle(tint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(kind.label))
        .accessibilityIdentifier("outcomeBadge.\(kind.rawValue)")
    }

    private var tint: AnyShapeStyle {
        switch kind {
        case .succeeded:
            AnyShapeStyle(Color.green)

        case .failed, .bypass:
            AnyShapeStyle(Color.red)

        case .timedOut:
            AnyShapeStyle(Color.orange)

        case .stopped, .skipped:
            AnyShapeStyle(.secondary)

        case .running:
            AnyShapeStyle(Color.runningTint)

        case .upcoming:
            AnyShapeStyle(.tertiary)
        }
    }

    /// The badge for a run's outcome.
    public init(outcome: RunOutcome) {
        kind = OutcomeBadgeKind(outcome)
    }

    /// A badge that is not a run's outcome: upcoming or bypass.
    public init(kind: OutcomeBadgeKind) {
        self.kind = kind
    }
}

#Preview("succeeded — light") {
    OutcomeBadge(outcome: .succeeded).padding().preferredColorScheme(.light)
}

#Preview("succeeded — dark") {
    OutcomeBadge(outcome: .succeeded).padding().preferredColorScheme(.dark)
}

#Preview("failed — light") { OutcomeBadge(outcome: .failed).padding().preferredColorScheme(.light) }
#Preview("failed — dark") { OutcomeBadge(outcome: .failed).padding().preferredColorScheme(.dark) }
#Preview("timed out — light") {
    OutcomeBadge(outcome: .timedOut).padding().preferredColorScheme(.light)
}

#Preview("timed out — dark") {
    OutcomeBadge(outcome: .timedOut).padding().preferredColorScheme(.dark)
}

#Preview("stopped — light") {
    OutcomeBadge(outcome: .stopped).padding().preferredColorScheme(.light)
}

#Preview("stopped — dark") { OutcomeBadge(outcome: .stopped).padding().preferredColorScheme(.dark) }
#Preview("skipped — light") {
    OutcomeBadge(outcome: .skipped).padding().preferredColorScheme(.light)
}

#Preview("skipped — dark") { OutcomeBadge(outcome: .skipped).padding().preferredColorScheme(.dark) }
#Preview("running — light") {
    OutcomeBadge(outcome: .running).padding().preferredColorScheme(.light)
}

#Preview("running — dark") { OutcomeBadge(outcome: .running).padding().preferredColorScheme(.dark) }
#Preview("upcoming — light") { OutcomeBadge(kind: .upcoming).padding().preferredColorScheme(.light)
}

#Preview("upcoming — dark") { OutcomeBadge(kind: .upcoming).padding().preferredColorScheme(.dark) }
#Preview("bypass — light") { OutcomeBadge(kind: .bypass).padding().preferredColorScheme(.light) }
#Preview("bypass — dark") { OutcomeBadge(kind: .bypass).padding().preferredColorScheme(.dark) }
#Preview("all — light") {
    VStack(alignment: .leading, spacing: DesignLock.spacingS) {
        ForEach(OutcomeBadgeKind.allCases, id: \.self) { kind in
            OutcomeBadge(kind: kind)
        }
    }
    .padding(DesignLock.popoverPadding)
    .preferredColorScheme(.light)
}

#Preview("all — dark") {
    VStack(alignment: .leading, spacing: DesignLock.spacingS) {
        ForEach(OutcomeBadgeKind.allCases, id: \.self) { kind in
            OutcomeBadge(kind: kind)
        }
    }
    .padding(DesignLock.popoverPadding)
    .preferredColorScheme(.dark)
}
