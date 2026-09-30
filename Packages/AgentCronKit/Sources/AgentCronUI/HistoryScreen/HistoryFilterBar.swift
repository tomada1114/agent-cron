import AgentCronCore
import SwiftUI

/// The job and outcome pickers above the list.
struct HistoryFilterBar: View {
    let history: HistoryModel

    var body: some View {
        HStack(spacing: DesignLock.spacingS) {
            Picker(selection: Binding(
                get: { history.jobFilter },
                set: { history.jobFilter = $0 },
            )) {
                Text(HistoryScreenText.allJobs).tag(UUID?.none)
                ForEach(history.jobFilterOptions) { option in
                    Text(option.title).tag(UUID?.some(option.id))
                }
            } label: {
                Text(HistoryScreenText.jobFilterLabel)
            }
            .accessibilityIdentifier("historyJobFilter")
            Picker(selection: Binding(
                get: { history.outcomeFilter },
                set: { history.outcomeFilter = $0 },
            )) {
                ForEach(HistoryOutcomeFilter.pickerOrder) { filter in
                    Text(filter.title).tag(filter)
                }
            } label: {
                Text(HistoryScreenText.outcomeFilterLabel)
            }
            .accessibilityIdentifier("historyOutcomeFilter")
        }
        .labelsHidden()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
