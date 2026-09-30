// swift-tools-version: 6.2
import PackageDescription

/// Strictness from day one: Swift 6 language mode (data-race safety as errors)
/// and every warning treated as an error. There is never a "legacy" codebase.
let strictSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .treatAllWarnings(as: .error),
]

let package = Package(
    name: "AgentCronKit",
    // The language the String Catalog is written in, and the one a reader falls back to
    // when the catalog lacks theirs. A second language is an ADR (`localizing-the-app`).
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AgentCronCore", targets: ["AgentCronCore"]),
        .library(name: "AgentCronUI", targets: ["AgentCronUI"]),
        .library(name: "AgentCronPlatform", targets: ["AgentCronPlatform"]),
    ],
    targets: [
        // Core owns the user-facing wording (it returns `LocalizedStringResource`), so the
        // one String Catalog lives here. xcodebuild compiles it into Core's resource
        // bundle; `swift build` only copies it, so tests read English from `defaultValue`.
        .target(
            name: "AgentCronCore",
            resources: [.process("Resources/Localizable.xcstrings")],
            swiftSettings: strictSettings,
        ),
        .target(
            name: "AgentCronUI",
            dependencies: ["AgentCronCore"],
            // `RunningTint` lives here, not in App/Assets.xcassets: a package view looks a
            // named color up in its own bundle (`bundle: .module`), which previews and
            // tests can see and the app's catalog is not.
            resources: [.process("Resources/Colors.xcassets")],
            swiftSettings: strictSettings,
        ),
        // OS-integration adapters behind Core-declared ports. Depends on AgentCronCore
        // only: it must not see AgentCronUI, and AgentCronUI must not see it (enforced by
        // ArchitectureBoundaryTests, since SwiftPM cannot stop a system framework
        // import and this graph alone would not stop a later dependency edit).
        .target(
            name: "AgentCronPlatform",
            dependencies: ["AgentCronCore"],
            swiftSettings: strictSettings,
        ),
        // Test code both test targets share: the fake of each Core port and the contract
        // function every implementation of that port must pass. It is a library target
        // only because a test target cannot be depended on, and it is test code all the
        // same: no product exports it, so `App/` cannot link it, ArchitectureBoundaryTests
        // fails if a shipped module imports it, and its sources sit under Tests/ — outside
        // scripts/coverage.sh's Sources/AgentCronCore filter, so it is never counted as Core.
        .target(
            name: "AgentCronTestSupport",
            dependencies: ["AgentCronCore"],
            path: "Tests/AgentCronTestSupport",
            swiftSettings: strictSettings,
        ),
        // The checked-in samples of each file format the app writes (`Fixtures/`), copied
        // as they are so a test decodes exactly the bytes a user's disk would hold.
        .testTarget(
            name: "AgentCronCoreTests",
            dependencies: ["AgentCronCore", "AgentCronTestSupport"],
            resources: [.copy("Fixtures")],
            swiftSettings: strictSettings,
        ),
        // Local-machine tests for the adapters: they talk to the real OS, which a CI
        // runner cannot (no logged-in GUI session, and no way to grant Accessibility,
        // Input Monitoring, or Screen Recording). Every suite here carries the
        // `.requiresLocalMachine` trait, so the tests are reported as skipped unless
        // RUN_LOCAL_MACHINE_TESTS=1 is set — `just test-local` sets it. Linking
        // AgentCronPlatform does not put it inside the coverage floor: scripts/coverage.sh
        // measures Sources/AgentCronCore and nothing else.
        .testTarget(
            name: "AgentCronPlatformTests",
            dependencies: ["AgentCronPlatform", "AgentCronCore", "AgentCronTestSupport"],
            swiftSettings: strictSettings,
        ),
    ],
)
