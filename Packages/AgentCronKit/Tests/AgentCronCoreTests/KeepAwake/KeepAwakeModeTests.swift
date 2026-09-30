import AgentCronCore
import Testing

@Suite("KeepAwakeMode")
struct KeepAwakeModeTests {
    @Test(arguments: [
        (KeepAwakeMode.off, nil),
        (KeepAwakeMode.oneHour, Duration.seconds(3_600)),
        (KeepAwakeMode.fourHours, Duration.seconds(14_400)),
        (KeepAwakeMode.untilTurnedOff, nil),
    ] as [(KeepAwakeMode, Duration?)])
    func `each choice lasts what its name says`(mode: KeepAwakeMode, expected: Duration?) {
        #expect(mode.duration == expected)
    }

    @Test
    func `there are exactly the four choices ux-flows F5 names`() {
        #expect(Set(KeepAwakeMode.allCases) == [.off, .oneHour, .fourHours, .untilTurnedOff])
    }
}
