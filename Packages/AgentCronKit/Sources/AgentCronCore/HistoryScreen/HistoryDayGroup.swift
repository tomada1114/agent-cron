import Foundation

/// One day of the History list: its runs, newest first.
public struct HistoryDayGroup: Sendable, Identifiable {
    /// The start of the day, in the model's calendar.
    public let id: Date
    /// "Today", "Yesterday", or the date.
    public let title: LocalizedStringResource
    /// The day's runs that pass the filters, newest first.
    public let rows: [HistoryRow]
}
