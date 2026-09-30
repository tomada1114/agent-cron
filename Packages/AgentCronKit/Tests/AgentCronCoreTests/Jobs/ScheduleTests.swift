import AgentCronCore
import Foundation
import Testing

@Suite("Schedule")
struct ScheduleTests {
    // MARK: - TimeOfDay

    @Test(arguments: [(0, 0), (23, 59), (9, 30)])
    func `a time inside 00:00 to 23:59 is accepted`(hour: Int, minute: Int) throws {
        let time = try TimeOfDay(hour: hour, minute: minute)
        #expect(time.hour == hour)
        #expect(time.minute == minute)
    }

    @Test(arguments: [(24, 0), (-1, 0), (0, 60), (0, -1), (25, 75)])
    func `a time outside 00:00 to 23:59 throws with the offending values`(
        hour: Int,
        minute: Int,
    ) {
        #expect(throws: TimeOfDayError.outOfRange(hour: hour, minute: minute)) {
            try TimeOfDay(hour: hour, minute: minute)
        }
    }

    @Test
    func `times order by hour, then minute`() {
        let times = [
            Fixture.time(10, 0),
            Fixture.time(9, 1),
            Fixture.time(8, 59),
            Fixture.time(9, 0),
        ]
        #expect(times.sorted() == [
            Fixture.time(8, 59),
            Fixture.time(9, 0),
            Fixture.time(9, 1),
            Fixture.time(10, 0),
        ])
    }

    @Test
    func `a time is encoded as its hour and minute`() throws {
        let data = try JSONEncoder().encode(Fixture.time(7, 45))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Int])
        #expect(object == ["hour": 7, "minute": 45])
    }

    @Test(arguments: [#"{"hour":24,"minute":0}"#, #"{"hour":0,"minute":60}"#])
    func `decoding an out-of-range time fails rather than inventing one`(json: String) {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TimeOfDay.self, from: Data(json.utf8))
        }
    }

    // MARK: - Weekday

    @Test
    func `weekdays run Monday to Sunday and persist as lowercase English names`() {
        #expect(Weekday.allCases.map(\.rawValue) == [
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        ])
    }

    @Test
    func `weekdays order Monday first`() {
        #expect(Set(Weekday.allCases).sorted() == Weekday.allCases)
        #expect(Weekday.monday < Weekday.sunday)
        #expect(!(Weekday.sunday < Weekday.saturday))
    }

    // MARK: - Schedule

    @Test
    func `a schedule keeps its times in ascending order`() {
        let schedule = Schedule(
            weekdays: [.monday],
            times: [Fixture.time(18, 0), Fixture.time(9, 0), Fixture.time(12, 0)],
        )
        #expect(schedule.times == [Fixture.time(9, 0), Fixture.time(12, 0), Fixture.time(18, 0)])
    }

    @Test
    func `a time added later lands in order`() {
        var schedule = Schedule(weekdays: [.monday], times: [Fixture.time(18, 0)])
        schedule.times.append(Fixture.time(6, 30))
        #expect(schedule.times == [Fixture.time(6, 30), Fixture.time(18, 0)])
    }

    @Test
    func `a schedule keeps a duplicate time so validation can report it`() {
        let schedule = Schedule(
            weekdays: [.monday],
            times: [Fixture.time(9, 0), Fixture.time(9, 0)],
        )
        #expect(schedule.times == [Fixture.time(9, 0), Fixture.time(9, 0)])
    }

    @Test
    func `a schedule encodes its weekdays Monday first, whatever the set's order`() throws {
        let schedule = Schedule(weekdays: [.sunday, .wednesday, .monday], times: [])
        let data = try JSONEncoder().encode(schedule)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["weekdays"] as? [String] == ["monday", "wednesday", "sunday"])
    }

    @Test
    func `a schedule decoded from unordered times holds them in order`() throws {
        let json = #"{"weekdays":["friday","monday"],"times":[{"hour":18,"minute":0},{"hour":9,"minute":0}]}"#
        let schedule = try JSONDecoder().decode(Schedule.self, from: Data(json.utf8))
        #expect(schedule.weekdays == [.monday, .friday])
        #expect(schedule.times == [Fixture.time(9, 0), Fixture.time(18, 0)])
    }

    @Test
    func `a schedule survives a JSON round trip unchanged`() throws {
        let schedule = Schedule(
            weekdays: Set(Weekday.allCases),
            times: [Fixture.time(0, 0), Fixture.time(12, 30), Fixture.time(23, 59)],
        )
        #expect(try Fixture.roundTrip(schedule) == schedule)
    }
}
