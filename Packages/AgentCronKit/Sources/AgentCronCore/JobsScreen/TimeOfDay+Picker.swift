import Foundation

/// The job editor's time pickers edit a `Date`, while a schedule holds wall-clock times;
/// these convert between the two on one fixed day, so a picker never meets a DST gap.
extension TimeOfDay {
    /// The day every picker date falls on: 2001-01-01, when no time zone changes its
    /// clock.
    private static let pickerDay = Date(timeIntervalSinceReferenceDate: 0)

    /// The time a picker showing `date` in `calendar` stands for, to the minute.
    public init(pickedFrom date: Date, in calendar: Calendar) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        self.init(checkedHour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    /// A time from parts already known to be in range; out-of-range parts are clamped
    /// rather than trapping, which a calendar's answer never needs.
    init(checkedHour hour: Int, minute: Int) {
        self.hour = min(max(hour, Self.hours.lowerBound), Self.hours.upperBound)
        self.minute = min(max(minute, Self.minutes.lowerBound), Self.minutes.upperBound)
    }

    /// The date a picker in `calendar` shows for this time.
    public func pickerDate(in calendar: Calendar) -> Date {
        let dayStart = calendar.startOfDay(for: Self.pickerDay)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart)
            ?? dayStart
    }
}
