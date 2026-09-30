/// Why a ``TimeOfDay`` could not be made.
public enum TimeOfDayError: Error, Equatable, Sendable {
    /// The hour is outside 0–23 or the minute outside 0–59; both values are carried so a
    /// caller can say which.
    case outOfRange(hour: Int, minute: Int)
}

/// A wall-clock time, hour and minute, at which a job fires in the local time zone.
///
/// Its range is checked when it is made — by the initializer and by decoding alike — so
/// the schedule math never meets a 24:00 or a 09:60.
public struct TimeOfDay: Sendable, Hashable, Comparable, Codable {
    private enum CodingKeys: String, CodingKey {
        case hour
        case minute
    }

    /// The hours a time may name.
    public static let hours = 0 ... 23
    /// The minutes a time may name.
    public static let minutes = 0 ... 59

    /// The hour, 0–23.
    public let hour: Int
    /// The minute, 0–59.
    public let minute: Int

    /// Makes a time, refusing one that no clock shows.
    /// - Throws: ``TimeOfDayError/outOfRange(hour:minute:)`` when either part is out of
    ///   range.
    public init(hour: Int, minute: Int) throws(TimeOfDayError) {
        guard Self.hours.contains(hour), Self.minutes.contains(minute) else {
            throw .outOfRange(hour: hour, minute: minute)
        }
        self.hour = hour
        self.minute = minute
    }

    /// Decodes `{"hour": …, "minute": …}`, failing on an out-of-range value rather than
    /// holding a time the scheduler cannot fire.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedHour = try container.decode(Int.self, forKey: .hour)
        let decodedMinute = try container.decode(Int.self, forKey: .minute)
        do {
            try self.init(hour: decodedHour, minute: decodedMinute)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .hour,
                in: container,
                debugDescription: "\(decodedHour):\(decodedMinute) is not a time of day",
            )
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }
}
