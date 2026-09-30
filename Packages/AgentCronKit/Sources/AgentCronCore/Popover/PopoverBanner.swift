import Foundation

/// The popover's banner copy (`docs/design/ux-guidelines.md` › States).
public enum PopoverBanner {
    /// Shown while ``PopoverModel/isAgentMissing`` is `true`.
    public static var agentNotFound: LocalizedStringResource {
        LocalizedStringResource(
            "popover.banner.agentNotFound",
            defaultValue: "claude was not found in your login shell.",
            bundle: .module,
            comment: "Menu-bar popover banner when the claude CLI does not resolve in the login shell.",
        )
    }
}
