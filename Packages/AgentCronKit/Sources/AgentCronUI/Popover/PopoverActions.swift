import AgentCronCore
import Foundation

/// What the popover's controls do, gathered so each part takes one value.
struct PopoverActions {
    let openRun: (UUID) -> Void
    let open: (MainSection) -> Void
    let newJob: () -> Void
    let openMainWindow: () -> Void
    let stop: (UUID) -> Void
    let quit: () -> Void
}
