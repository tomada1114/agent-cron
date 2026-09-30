import AgentCronCore
import Foundation
import Testing

@Suite("ProcessOutcome")
struct ProcessOutcomeTests {
    @Test
    func `an outcome keeps the output, the status, and what ended the process`() {
        let outcome = ProcessOutcome(
            stdout: Data([0x7B, 0x7D, 0x0A]),
            stderr: "warning\n",
            exitCode: 143,
            terminatedBy: .timeout,
        )
        #expect(outcome.stdout == Data("{}\n".utf8))
        #expect(outcome.stderr == "warning\n")
        #expect(outcome.exitCode == 143)
        #expect(outcome.terminatedBy == .timeout)
    }

    @Test
    func `a process that never started ended on its own, wrote nothing, and says why on stderr`() {
        let outcome = ProcessOutcome.notLaunched(errorCode: 4)
        #expect(outcome.terminatedBy == .exit)
        #expect(outcome.exitCode == -1)
        #expect(outcome.stdout.isEmpty)
        #expect(outcome.stderr == """
        agentcron: could not start the process (error 4); check that the job's directory \
        exists

        """)
    }

    @Test
    func `the not-launched status is one no process can exit with`() {
        // A process's status is 0 ... 255, and a signal's 128 + 1 ... 128 + 31 within it.
        #expect(!(0 ... 255).contains(ProcessOutcome.notLaunchedExitCode))
    }
}
