import Foundation
import os

/// What ``ProcessAgentRunner`` knows about one process it launched: whether the process
/// has exited, and what it has written so far — gathered from the `Process` termination
/// handler and the two pipes' readability handlers, which call in on queues of their own.
///
/// Both pipes are drained as data arrives, so a process that writes more than a pipe
/// buffer holds never blocks on a full pipe while the runner waits for it to exit.
final class LaunchedProcess: Sendable {
    /// A point in a process's end that a caller can wait for.
    enum Milestone {
        /// The process itself has exited and been reaped.
        case exited
        /// It has exited, and every process holding its stdout or stderr has closed them.
        case drained
    }

    private enum Stream {
        case stderr
        case stdout
    }

    /// What the process wrote, and its status once it has exited.
    struct Collected {
        let stdout: Data
        let stderr: Data
        let exitCode: Int32?
    }

    /// Whether a new waiter was answered at once or must wait for an event.
    private enum Registration {
        case answered(Bool)
        case registered
    }

    private struct Waiter {
        let milestone: Milestone
        let continuation: CheckedContinuation<Bool, Never>
    }

    private struct State {
        var exitCode: Int32?
        var stdout = Data()
        var stderr = Data()
        var openStreams: Set<Stream> = [.stderr, .stdout]
        var nextWaiterID = 0
        var waiters: [Int: Waiter] = [:]

        func reached(_ milestone: Milestone) -> Bool {
            switch milestone {
            case .exited:
                exitCode != nil

            case .drained:
                exitCode != nil && openStreams.isEmpty
            }
        }

        /// Removes and returns every waiter whose milestone has now been reached.
        mutating func takeSatisfiedWaiters() -> [Waiter] {
            let satisfied = waiters.filter { reached($0.value.milestone) }
            for id in satisfied.keys {
                waiters.removeValue(forKey: id)
            }
            return Array(satisfied.values)
        }
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let stdoutHandle: FileHandle
    private let stderrHandle: FileHandle

    /// Starts collecting what the process writes to the read ends of its two pipes.
    init(stdout: FileHandle, stderr: FileHandle) {
        stdoutHandle = stdout
        stderrHandle = stderr
        collect(from: stdout, into: .stdout)
        collect(from: stderr, into: .stderr)
    }

    /// Records that the process exited with `exitCode`, as a shell reports it.
    func exited(with exitCode: Int32) {
        update { $0.exitCode = exitCode }
    }

    /// Waits until `milestone` is reached and answers `true`, or answers `false` as soon
    /// as the waiting task is cancelled first.
    func wait(for milestone: Milestone) async -> Bool {
        let id = state.withLock { current in
            current.nextWaiterID += 1
            return current.nextWaiterID
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // Checked under the lock the cancellation handler also takes, so a
                // cancellation either sees this waiter registered or is seen here.
                let registration = state.withLock { current in
                    if current.reached(milestone) {
                        return Registration.answered(true)
                    }
                    if Task.isCancelled {
                        return .answered(false)
                    }
                    current.waiters[id] = Waiter(milestone: milestone, continuation: continuation)
                    return .registered
                }
                if case let .answered(reached) = registration {
                    continuation.resume(returning: reached)
                }
            }
        } onCancel: {
            let waiter = state.withLock { $0.waiters.removeValue(forKey: id) }
            waiter?.continuation.resume(returning: false)
        }
    }

    /// Waits until `milestone` is reached (`true`) or `limit` has passed (`false`).
    ///
    /// The wait runs in a task of its own so that the caller's cancellation — a Stop —
    /// cannot cut short the grace period a terminated process is given.
    func wait(for milestone: Milestone, atMost limit: Duration) async -> Bool {
        await Task {
            await withTaskGroup(of: Bool.self) { group in
                group.addTask { await self.wait(for: milestone) }
                group.addTask {
                    try? await Task.sleep(for: limit)
                    return false
                }
                let first = await group.next() ?? false
                group.cancelAll()
                return first
            }
        }.value
    }

    /// Stops collecting output and answers what was collected, and the exit status if the
    /// process has exited.
    func finish() -> Collected {
        stdoutHandle.readabilityHandler = nil
        stderrHandle.readabilityHandler = nil
        return state.withLock { current in
            Collected(stdout: current.stdout, stderr: current.stderr, exitCode: current.exitCode)
        }
    }

    private func collect(from handle: FileHandle, into stream: Stream) {
        handle.readabilityHandler = { [weak self] readable in
            let chunk = readable.availableData
            guard !chunk.isEmpty else {
                // An empty read is end of file: every writer has closed this pipe.
                readable.readabilityHandler = nil
                self?.update { _ = $0.openStreams.remove(stream) }
                return
            }
            self?.update { current in
                switch stream {
                case .stderr:
                    current.stderr.append(chunk)

                case .stdout:
                    current.stdout.append(chunk)
                }
            }
        }
    }

    private func update(_ change: @Sendable (inout State) -> Void) {
        let satisfied = state.withLock { current in
            change(&current)
            return current.takeSatisfiedWaiters()
        }
        for waiter in satisfied {
            waiter.continuation.resume(returning: true)
        }
    }
}
