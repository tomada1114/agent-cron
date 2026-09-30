import AgentCronCore
import AgentCronPlatform
import AgentCronTestSupport
import Foundation
import Testing

/// `ProcessAgentRunner` against real processes launched through the real login shell —
/// what a Core test with `FakeAgentRunner` cannot show: that argv arrives intact, the
/// login shell supplies the PATH, the working directory is the job's, and a timeout or a
/// Stop really ends the process and everything it left in its process group.
///
/// Beside it sits the adapter half of the port's contract suite: `AgentRunningContract`,
/// the same function `AgentCronCoreTests` runs against the fake on every `just test`.
///
/// It needs no TCC grant and shows no window — only a real Mac with `/bin/zsh`. Every
/// process a test starts is gone before the test ends: the long-running ones sleep for a
/// duration unique to the test, which `pgrep` looks for afterwards.
@Suite("ProcessAgentRunner against real processes", .requiresLocalMachine)
struct ProcessAgentRunnerTests {
    /// A fresh directory for one test, removed by the caller.
    static func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "AgentCronTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }

    /// A `sleep` duration no other process on the Mac is using — about 30 seconds, well
    /// past any test here — so `pgrep -f` finds exactly the processes this test started.
    static func uniqueSleepSeconds() -> String {
        "30.\(Int.random(in: 100_000 ... 999_999))"
    }

    /// Whether any process's command line contains `marker`, as `pgrep -f` sees it.
    static func isRunning(_ marker: String) throws -> Bool {
        let pgrep = Process()
        pgrep.executableURL = URL(filePath: "/usr/bin/pgrep")
        pgrep.arguments = ["-f", marker]
        pgrep.standardOutput = FileHandle.nullDevice
        try pgrep.run()
        pgrep.waitUntilExit()
        // pgrep exits 0 when a process matched, 1 when none did, and 2 or 3 on an error.
        try #require(pgrep.terminationStatus <= 1, "pgrep exited \(pgrep.terminationStatus)")
        return pgrep.terminationStatus == 0
    }

    /// Ends the processes a test deliberately left running, recording an issue if any
    /// could not be ended.
    static func endStraggler(_ marker: String) {
        let pkill = Process()
        pkill.executableURL = URL(filePath: "/usr/bin/pkill")
        pkill.arguments = ["-KILL", "-f", marker]
        do {
            try pkill.run()
            pkill.waitUntilExit()
            #expect(try !isRunning(marker), "a process matching \(marker) is still running")
        } catch {
            Issue.record("could not end the processes matching \(marker): \(error)")
        }
    }

    @Test
    func `the issue's example: echo in a directory answers its output and status 0`() async throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let outcome = await ProcessAgentRunner().run(
            argv: ["/bin/echo", "hello world"],
            directory: directory,
            timeout: .seconds(5),
        )
        #expect(outcome == ProcessOutcome(
            stdout: Data("hello world\n".utf8),
            stderr: "",
            exitCode: 0,
            terminatedBy: .exit,
        ))
    }

    @Test
    func `the process runs in the job's directory`() async throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let outcome = await ProcessAgentRunner().run(
            argv: ["/bin/pwd", "-P"],
            directory: directory,
            timeout: .seconds(5),
        )
        let printed = try #require(String(bytes: outcome.stdout, encoding: .utf8))
        try #require(printed.hasSuffix("\n"), "pwd printed \(printed)")
        // `pwd -P` prints /private/var/…, the temporary directory's physical path; resolve
        // both sides the same way rather than compare spellings of one directory.
        let workingDirectory = URL(
            filePath: String(printed.dropLast()),
            directoryHint: .isDirectory,
        )
        #expect(workingDirectory.resolvingSymlinksInPath() == directory.resolvingSymlinksInPath())
    }

    @Test
    func `the login shell, not the caller, supplies the PATH`() async throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        // Roughly what launchd hands an app opened from the Finder.
        let bare = ["HOME": home, "PATH": "/usr/bin:/bin", "USER": NSUserName()]

        let outcome = await ProcessAgentRunner(environment: bare).run(
            argv: ["/usr/bin/printenv", "PATH"],
            directory: directory,
            timeout: .seconds(10),
        )
        let path = try #require(String(bytes: outcome.stdout, encoding: .utf8))
            .trimmingCharacters(in: .newlines)
            .split(separator: ":")
            .map(String.init)
        // /etc/zprofile's path_helper puts every /etc/paths entry on a login shell's PATH.
        let systemPaths = try String(contentsOfFile: "/etc/paths", encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)
        #expect(systemPaths.contains("/usr/local/bin"))
        for entry in systemPaths {
            #expect(path.contains(entry), "PATH \(path) lacks \(entry)")
        }
    }

    @Test
    func `a timeout ends the process with SIGTERM and answers timeout`() async throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let marker = Self.uniqueSleepSeconds()

        let clock = ContinuousClock()
        let start = clock.now
        let outcome = await ProcessAgentRunner().run(
            argv: ["/bin/sleep", marker],
            directory: directory,
            timeout: .seconds(1),
        )
        let elapsed = clock.now - start
        #expect(outcome.terminatedBy == .timeout)
        #expect(outcome.exitCode == 143)
        #expect(elapsed >= .seconds(1))
        #expect(elapsed < .seconds(5), "SIGTERM should have sufficed, took \(elapsed)")
        #expect(try !Self.isRunning(marker))
    }

    @Test
    func `a process that ignores SIGTERM gets SIGKILL 10 seconds later`() async throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let marker = Self.uniqueSleepSeconds()

        let clock = ContinuousClock()
        let start = clock.now
        let outcome = await ProcessAgentRunner().run(
            // The shell ignores SIGTERM, and so does the sleep it starts, which inherits
            // the disposition — only SIGKILL to the whole group ends both.
            argv: ["/bin/sh", "-c", #"trap '' TERM; /bin/sleep "$1"; echo woke"#, "sh", marker],
            directory: directory,
            timeout: .seconds(1),
        )
        let elapsed = clock.now - start
        #expect(outcome.terminatedBy == .timeout)
        #expect(outcome.exitCode == 137)
        #expect(outcome.stdout.isEmpty)
        #expect(elapsed >= .seconds(11))
        #expect(elapsed < .seconds(16), "SIGKILL should follow 10 s after SIGTERM, took \(elapsed)")
        #expect(try !Self.isRunning(marker))
    }

    @Test
    func `cancelling the task while the process runs stops it`() async throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let marker = Self.uniqueSleepSeconds()

        let run = Task {
            await ProcessAgentRunner().run(
                argv: ["/bin/sleep", marker],
                directory: directory,
                timeout: .seconds(60),
            )
        }
        // Stop only once the process is really running, as a user would.
        var attempts = 0
        while try !Self.isRunning(marker), attempts < 100 {
            attempts += 1
            try await Task.sleep(for: .milliseconds(100))
        }
        try #require(try Self.isRunning(marker), "the process never started")
        run.cancel()
        let outcome = await run.value

        #expect(outcome.terminatedBy == .stopped)
        #expect(outcome.exitCode == 143)
        #expect(try !Self.isRunning(marker))
    }

    @Test
    func `a process a signal ends reports 128 plus the signal, as a shell would`() async throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let outcome = await ProcessAgentRunner().run(
            argv: ["/bin/sh", "-c", "kill -USR1 $$"],
            directory: directory,
            timeout: .seconds(5),
        )
        #expect(outcome.terminatedBy == .exit)
        #expect(outcome.exitCode == 128 + 30)
    }

    @Test
    func `output larger than a pipe buffer arrives whole, on both streams`() async throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let outcome = await ProcessAgentRunner().run(
            argv: ["/bin/sh", "-c", "head -c 300000 /dev/zero; head -c 200000 /dev/zero >&2"],
            directory: directory,
            timeout: .seconds(10),
        )
        #expect(outcome.terminatedBy == .exit)
        #expect(outcome.stdout.count == 300_000)
        #expect(outcome.stderr.utf8.count == 200_000)
    }

    @Test
    func `a process left holding the output open cannot turn an exit into a hang`() async throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let marker = Self.uniqueSleepSeconds()
        defer { Self.endStraggler(marker) }

        let clock = ContinuousClock()
        let start = clock.now
        let outcome = await ProcessAgentRunner().run(
            // The background sleep inherits stdout and outlives the shell that started it.
            argv: ["/bin/sh", "-c", #"/bin/sleep "$1" & echo done"#, "sh", marker],
            directory: directory,
            timeout: .seconds(60),
        )
        let elapsed = clock.now - start
        #expect(outcome == ProcessOutcome(
            stdout: Data("done\n".utf8),
            stderr: "",
            exitCode: 0,
            terminatedBy: .exit,
        ))
        #expect(elapsed < .seconds(15), "waited \(elapsed) for the straggler")
    }

    @Test
    func `keeps the AgentRunning contract the fake is held to`() async throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        await AgentRunningContract.check(ProcessAgentRunner(), in: directory, timeout: .seconds(1))
    }
}
