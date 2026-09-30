# Observing behavior with no human at the keyboard

Three ways to watch a running build: a screenshot, a throwaway UI test that drives a
flow, and a launch that starts the app in a known state. Every command here was run
against this template's own app. Write every artifact to a scratch directory outside the
checkout — nothing below belongs in a commit.

## Screenshot

The whole screen, silently:

```bash
screencapture -x /tmp/shot.png
```

One window, without the drop shadow, which needs the window's CGWindowID:

```bash
screencapture -x -o -l "$window_id" /tmp/window.png
```

macOS ships no command that prints that id, so ask CoreGraphics for it. This snippet
prints the id of every on-screen, layer-0 (ordinary, non-panel) window owned by a
process name — save it to your scratch directory, not into the repository:

```swift
import CoreGraphics
import Foundation

let owner = CommandLine.arguments.dropFirst().first ?? ""
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
    as? [[String: Any]] ?? []
for window in list {
    guard window[kCGWindowOwnerName as String] as? String == owner,
          let number = window[kCGWindowNumber as String] as? Int,
          let layer = window[kCGWindowLayer as String] as? Int, layer == 0
    else { continue }
    print(number)
}
```

```bash
swift /tmp/windowid.swift AgentCron     # prints one id per window
```

Reading the window list needs no permission; **capturing pixels does**. Screen Recording
is granted to the application that runs `screencapture` — your terminal, or whatever
launched the agent — not to this app, and it is a first-run TCC prompt like any other,
so it belongs in the single up-front ask. A denied grant is worse than an error: the
capture still succeeds and still writes a PNG, showing the desktop where the windows
should be. Look at the file you wrote before believing it.

This app is a menu-bar agent (`LSUIElement`, `MenuBarExtra` — ADR-0001; **BACKGROUND:**
`starting-an-app`), so right after launch the snippet above prints nothing: the process
owns no window until the popover or the main window is open, and the status item itself
is not in its window list. Opening either is a click only a human or an accessibility
grant can make, which is what the XCUITest below does. A full-screen capture shows the
status item in the menu bar, and everything else on the screen with it — crop it to the
status item, the popover, or the window before it goes near a pull request.

## Drive a flow with a throwaway XCUITest

`LaunchUITests/` is the only XCTest target (`project.yml`'s `AgentCronLaunchUITests`, whose
`sources: [LaunchUITests]` takes the whole directory), so a probe is one file plus
`just generate`. What XCUITest can reach in this app is narrow, and measured:

- **The status item** is `app.menuBars.statusItems.firstMatch` (its `title` reads
  `Clock`, the symbol's name, not "AgentCron"). `click()` on it opens the popover.
- **The popover's content is invisible** to XCUITest — a `.window`-style `MenuBarExtra`
  exposes nothing to the app's accessibility tree, so its identifiers
  (`openMainWindowButton`, `frontmostAppLabel` in
  `Packages/AgentCronKit/Sources/AgentCronUI/ContentView.swift`) cannot be queried or
  clicked. A keyboard shortcut still reaches it: ⌘, while the popover is open presses
  **Open AgentCron…**. See it with `XCUIScreen.main.screenshot()`.
- **The main window** is `app.windows.firstMatch` once it is open; `app.windows` is empty
  before that. A new control there needs an accessibility identifier before a probe can
  drive it.

```swift
// LaunchUITests/ScratchProbeTests.swift — throwaway, never committed
import XCTest

final class ScratchProbeTests: XCTestCase {
    @MainActor
    func testProbe() {
        let app = XCUIApplication()
        app.launchArguments += ["-probeValue", "5"]
        app.launchEnvironment["PROBE_STATE"] = "known-state"
        app.launch()
        let statusItem = app.menuBars.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 10))
        statusItem.click()
        sleep(2) // the popover animates in; nothing in the tree says when it has
        let popover = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        popover.name = "popover-open"
        popover.lifetime = .keepAlways
        add(popover)
        app.typeKey(",", modifierFlags: .command) // the popover's Open AgentCron…
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "main-window-open"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
```

Run that one test, keeping the result bundle out of the way of `just uitest`'s own:

```bash
mise exec -- xcodegen generate
xcodebuild test -project AgentCron.xcodeproj -scheme AgentCron -destination 'platform=macOS' \
  -derivedDataPath build/dev-derived-data -resultBundlePath build/Probe.xcresult \
  -only-testing:AgentCronLaunchUITests/ScratchProbeTests
xcrun xcresulttool export attachments --path build/Probe.xcresult --output-path /tmp/att
```

The export writes each attachment under a UUID file name plus a `manifest.json` that
maps it back to `suggestedHumanReadableName` ("main-window-open_0_….png") and the
test it came from — read the manifest, then look at the PNG. `just uitest` runs the whole
scheme (the launch guarantee included) and writes `build/LaunchUITests.xcresult`; use it
when you want both, `-only-testing:` while iterating.

Two rules about the probe:

- **It is deleted before the pull request**, along with a re-run of `just generate`.
  `LaunchUITests/` holds the launch guarantee and nothing else; a behavior worth keeping
  is a `AgentCronCore` test against a fake, not a UI test (`.claude/rules/testing.md` ›
  Where a Test Goes). An XCUITest is slow, needs a GUI session, and asserts through the
  accessibility layer — everything a decision test should not be.
- **The first local XCUITest run may prompt for Accessibility** for whatever launched
  `xcodebuild`, exactly as the `just uitest` recipe warns. Same single up-front ask.

## Start the app in a known state

Nothing in this app reads a launch argument or an environment variable today: no `App/`
or `AgentCronCore` code consults `UserDefaults` or `ProcessInfo`. The two snippets here
pass `-probeValue 5` and `PROBE_STATE` to prove the plumbing, not because the app answers
them. **Do not add such a hook to the app just to observe it** — a state you only need to
*look at* is a state a Core test can construct directly, and a `#Preview` can show by
handing the view a view model already in that state.

When a hook is genuinely warranted — a state that is expensive or impossible to reach by
hand, wanted from both a UI probe and by hand — this is the mechanism, verified against a
running build:

```bash
open --env PROBE_STATE=known-state -n \
  build/dev-derived-data/Build/Products/Debug/AgentCron.app --args -probeValue 5
ps -o command= -p "$(pgrep -f 'Debug/AgentCron.app/Contents/MacOS/AgentCron' | head -1)"
```

- `--args` puts everything after it in the process's `argv`, which is also what fills
  `UserDefaults`' argument domain: a `-key value` pair there is what `UserDefaults
  .standard.string(forKey: "key")` reads, ahead of any stored value, for that launch
  only. `--env KEY=value` adds an environment variable, which `ProcessInfo` reads.
  `XCUIApplication.launchArguments` and `.launchEnvironment` are the same two channels
  from a UI test.
- `-n` opens a *new* instance even though one is running, which is how you end up
  watching two builds at once. Quit the verified pid first (`kill -TERM "$pid"`) unless you meant it.
- The hook itself belongs in `AgentCronCore`, behind one value a view model reads, so the
  same state stays reachable from a Core test. `App/` — the composition root — is where
  the argument is read and turned into that value, and Core never learns where it came
  from.
