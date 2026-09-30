import AgentCronCore
import SwiftUI

/// The editor's Schedule section (`docs/product/ux-flows.md` S2): the weekday chips and
/// presets, the times with their [−] buttons and Add Time, and the one-line summary.
struct JobScheduleSection: View {
    private enum Layout {
        /// The design lock's 24 × 24 pt floor for a clickable target (ADR-0009).
        static let minimumTarget: CGFloat = 24
    }

    let editor: JobEditorModel
    let focus: FocusState<JobEditorField?>.Binding

    @Environment(\.calendar)
    private var calendar

    var body: some View {
        Section {
            EditorRow(
                label: JobEditorField.days.title,
                message: editor.message(for: .days),
                identifier: "jobDays",
            ) {
                chips
                presets
            }
            EditorRow(
                label: JobEditorField.times.title,
                message: editor.message(for: .times),
                identifier: "jobTimes",
            ) {
                timeRows
                addTimeButton
            }
            if let summary = editor.scheduleSummary {
                Label {
                    Text(summary)
                } icon: {
                    Image(systemName: "arrow.right")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .accessibilityIdentifier("scheduleSummary")
            }
        } header: {
            Text(JobsScreenText.scheduleSection)
                .font(.headline)
        }
    }

    private var chips: some View {
        HStack(spacing: DesignLock.spacingXS) {
            ForEach(Weekday.allCases, id: \.self) { day in
                chip(day)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(editor.accessibilityLabel(for: .days)))
    }

    private var presets: some View {
        HStack(spacing: DesignLock.spacingS) {
            ForEach(SchedulePreset.allCases, id: \.self) { preset in
                Button {
                    editor.presetChosen(preset)
                } label: {
                    Text(preset.title)
                }
                .buttonStyle(.link)
                .accessibilityIdentifier("schedulePreset.\(preset)")
            }
        }
        .font(.callout)
    }

    private var timeRows: some View {
        ForEach(Array(editor.draft.schedule.times.enumerated()), id: \.offset) { index, time in
            HStack(spacing: DesignLock.spacingS) {
                DatePicker(
                    selection: Binding(
                        get: { time.pickerDate(in: calendar) },
                        set: { date in
                            editor.timeChanged(
                                at: index,
                                to: TimeOfDay(pickedFrom: date, in: calendar),
                            )
                        },
                    ),
                    displayedComponents: .hourAndMinute,
                ) {
                    Text(JobEditorField.times.title)
                }
                .labelsHidden()
                .datePickerStyle(.field)
                .focused(focus, equals: .times)
                .accessibilityIdentifier("timePicker.\(index)")
                Button {
                    editor.timeRemoved(at: index)
                } label: {
                    Image(systemName: "minus")
                        .frame(minWidth: Layout.minimumTarget, minHeight: Layout.minimumTarget)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text(editor.removeTimeLabel(for: time)))
                .accessibilityIdentifier("removeTimeButton.\(index)")
            }
        }
    }

    private var addTimeButton: some View {
        Button {
            editor.timeAdded(editor.suggestedNewTime)
        } label: {
            Label {
                Text(JobsScreenText.addTime)
            } icon: {
                Image(systemName: "plus")
            }
        }
        .focused(focus, equals: .times)
        .accessibilityIdentifier("addTimeButton")
    }

    /// A standard toggle in the button style, which VoiceOver reads as a toggle with its
    /// state; Space toggles it whenever it has focus (ux-guidelines › Accessibility
    /// targets), not only under Full Keyboard Access.
    @ViewBuilder
    private func chip(_ day: Weekday) -> some View {
        let chip = Toggle(
            isOn: Binding(
                get: { editor.draft.schedule.weekdays.contains(day) },
                set: { _ in editor.weekdayToggled(day) },
            ),
        ) {
            Text(day.shortName)
                .frame(minWidth: Layout.minimumTarget, minHeight: Layout.minimumTarget)
        }
        .toggleStyle(.button)
        .buttonBorderShape(.roundedRectangle(radius: DesignLock.chipCornerRadius))
        .onKeyPress(.space) {
            editor.weekdayToggled(day)
            return .handled
        }
        .accessibilityIdentifier("weekdayChip.\(day.rawValue)")
        // Only the first chip stands for the Days row, so a refused save that moves
        // focus there lands on Monday rather than on whichever chip SwiftUI picks.
        if day == Weekday.allCases.first {
            chip.focused(focus, equals: .days)
        } else {
            chip
        }
    }
}
