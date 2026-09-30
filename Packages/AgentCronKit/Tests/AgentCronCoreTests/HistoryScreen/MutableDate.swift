import AgentCronCore
import Foundation
import os

/// A date a test moves forward between calls.
final class MutableDate: Sendable {
    private let state: OSAllocatedUnfairLock<Date>

    var value: Date {
        get { state.withLock { $0 } }
        set { state.withLock { $0 = newValue } }
    }

    init(_ date: Date) {
        state = OSAllocatedUnfairLock(initialState: date)
    }
}
