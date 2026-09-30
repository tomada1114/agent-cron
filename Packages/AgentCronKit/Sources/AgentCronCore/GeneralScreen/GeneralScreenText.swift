import Foundation

/// The General screen's fixed wording (`docs/product/ux-flows.md` S4).
///
/// Each is a computed property so the resource is built afresh, in the locale current at
/// that moment, on every read (`localizing-the-app`).
public enum GeneralScreenText {
    /// The Startup section's heading.
    public static var startupHeading: LocalizedStringResource {
        LocalizedStringResource(
            "generalScreen.startup.heading",
            defaultValue: "Startup",
            bundle: .module,
            comment: "The General screen's heading over launch at login.",
        )
    }

    /// The launch-at-login toggle's label.
    public static var launchAtLogin: LocalizedStringResource {
        LocalizedStringResource(
            "generalScreen.startup.launchAtLogin",
            defaultValue: "Launch at login",
            bundle: .module,
            comment: "Label of the toggle that opens the app at login.",
        )
    }

    /// The button shown while the login item needs the user's approval.
    public static var openLoginItems: LocalizedStringResource {
        LocalizedStringResource(
            "generalScreen.startup.openLoginItems",
            defaultValue: "Open Login Items",
            bundle: .module,
            comment: "Button that opens System Settings › Login Items.",
        )
    }

    /// Why the toggle is on but the app will not open at login yet.
    public static var loginItemRequiresApproval: LocalizedStringResource {
        LocalizedStringResource(
            "generalScreen.startup.requiresApproval",
            defaultValue: "Allow AgentCron in System Settings › Login Items to open it at login.",
            bundle: .module,
            comment: "Note under the launch-at-login toggle while macOS waits for approval.",
        )
    }

    /// Why the toggle cannot be turned on.
    public static var loginItemNotFound: LocalizedStringResource {
        LocalizedStringResource(
            "generalScreen.startup.notFound",
            defaultValue: "macOS cannot find this copy of AgentCron. Move it to Applications and try again.",
            bundle: .module,
            comment: "Note under the launch-at-login toggle when macOS cannot find the app.",
        )
    }

    /// The Agents section's heading.
    public static var agentsHeading: LocalizedStringResource {
        LocalizedStringResource(
            "generalScreen.agents.heading",
            defaultValue: "Agents",
            bundle: .module,
            comment: "The General screen's heading over the agent checks.",
        )
    }

    /// The Claude Code row's name.
    public static var claudeCode: LocalizedStringResource {
        LocalizedStringResource(
            "generalScreen.agents.claudeCode",
            defaultValue: "Claude Code",
            bundle: .module,
            comment: "Name of the Claude Code agent row on the General screen.",
        )
    }

    /// Under a resolved path: where it was looked up.
    public static var resolvedViaLoginShell: LocalizedStringResource {
        LocalizedStringResource(
            "generalScreen.agent.resolvedViaLoginShell",
            defaultValue: "resolved via login shell",
            bundle: .module,
            comment: "Line under the resolved claude path, saying where it was looked up.",
        )
    }

    /// The Claude Code row's headline when `claude` does not resolve.
    public static var notFound: LocalizedStringResource {
        LocalizedStringResource(
            "generalScreen.agent.notFound",
            defaultValue: "claude was not found in your login shell (zsh -l)",
            bundle: .module,
            comment: "Shown on the Claude Code row when the login shell does not find claude.",
        )
    }

    /// What to do when `claude` does not resolve.
    public static var notFoundHint: LocalizedStringResource {
        LocalizedStringResource(
            "generalScreen.agent.notFoundHint",
            defaultValue: "Install Claude Code, or add its folder to PATH in your shell profile, then check again.",
            bundle: .module,
            comment: "Hint under the not-found message on the Claude Code row.",
        )
    }

    /// The button that reruns the agent check.
    public static var checkAgain: LocalizedStringResource {
        LocalizedStringResource(
            "generalScreen.agent.checkAgain",
            defaultValue: "Check Again",
            bundle: .module,
            comment: "Button that checks again whether claude resolves.",
        )
    }

    /// The spinner's label while a check is in flight.
    public static var checking: LocalizedStringResource {
        LocalizedStringResource(
            "generalScreen.agent.checking",
            defaultValue: "Checking…",
            bundle: .module,
            comment: "Accessibility label of the spinner on the Claude Code row.",
        )
    }

    /// The Keep awake section's heading.
    public static var keepAwakeHeading: LocalizedStringResource {
        LocalizedStringResource(
            "generalScreen.keepAwake.heading",
            defaultValue: "Keep awake",
            bundle: .module,
            comment: "The General screen's heading over keep-awake behavior.",
        )
    }

    /// The keep-awake row's label.
    public static var keepAwakeWhileRunning: LocalizedStringResource {
        LocalizedStringResource(
            "generalScreen.keepAwake.whileJobsRun",
            defaultValue: "Keep awake while jobs run",
            bundle: .module,
            comment: "Label of the keep-awake row on the General screen.",
        )
    }

    /// The keep-awake row's value: it cannot be turned off.
    public static var keepAwakeAlwaysOn: LocalizedStringResource {
        LocalizedStringResource(
            "generalScreen.keepAwake.alwaysOn",
            defaultValue: "Always on",
            bundle: .module,
            comment: "Value of the keep-awake row: the Mac never idle-sleeps while a job runs.",
        )
    }

    /// The History section's heading.
    public static var historyHeading: LocalizedStringResource {
        LocalizedStringResource(
            "generalScreen.history.heading",
            defaultValue: "History",
            bundle: .module,
            comment: "The General screen's heading over run retention.",
        )
    }

    /// How long runs are kept (requirements §3.4).
    public static var retention: LocalizedStringResource {
        LocalizedStringResource(
            "generalScreen.history.retention",
            defaultValue: "Runs are kept for 90 days.",
            bundle: .module,
            comment: "How long run history is kept, on the General screen.",
        )
    }
}
