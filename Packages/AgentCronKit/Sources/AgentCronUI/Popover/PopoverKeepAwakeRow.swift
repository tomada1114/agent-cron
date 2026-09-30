import AgentCronCore
import SwiftUI

/// The keep-awake menu and, for a timed choice, the time it has left.
struct PopoverKeepAwakeRow: View {
    let model: PopoverModel

    var body: some View {
        HStack(spacing: DesignLock.spacingS) {
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
            Spacer(minLength: 0)
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                if let remaining = model.remainingKeepAwakeTime {
                    Text(PopoverText.remaining(remaining))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("popoverKeepAwakeRemaining")
                }
            }
        }
    }
}
