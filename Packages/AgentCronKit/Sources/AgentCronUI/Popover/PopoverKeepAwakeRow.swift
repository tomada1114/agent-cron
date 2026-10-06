import AgentCronCore
import SwiftUI

/// The keep-awake menu and, for a timed choice, the time it has left.
struct PopoverKeepAwakeRow: View {
    let model: PopoverModel

    var body: some View {
        // Side by side when the remaining time fits; otherwise it moves below the menu
        // rather than truncating.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignLock.spacingS) {
                picker
                Spacer(minLength: 0)
                remainingTime
            }
            VStack(alignment: .leading, spacing: DesignLock.spacingXS) {
                picker
                remainingTime
            }
        }
    }

    private var picker: some View {
        Picker(selection: Binding(
            get: { model.keepAwakeMode },
            set: { model.chooseKeepAwake($0) },
        )) {
            ForEach(KeepAwakeMode.menuOrder, id: \.self) { mode in
                Text(mode.label).tag(mode)
            }
        } label: {
            Label {
                Text(PopoverText.keepAwake)
            } icon: {
                Image(systemName: "cup.and.saucer")
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
        .accessibilityIdentifier("popoverKeepAwake")
    }

    private var remainingTime: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            if let timeLeft = model.remainingKeepAwakeTime {
                Text(PopoverText.remaining(timeLeft))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .accessibilityIdentifier("popoverKeepAwakeRemaining")
            }
        }
    }
}
