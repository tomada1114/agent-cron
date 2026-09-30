import Foundation

/// The status item's `.window`-style popover (ADR-0001), the app's resident surface.
public enum MenuBarPopover {
    /// What the popover shows until the run timeline replaces the placeholder
    /// (`docs/product/ux-flows.md` S1).
    public static var placeholder: LocalizedStringResource {
        LocalizedStringResource(
            "menuBarPopover.placeholder",
            defaultValue: "Scheduled runs will appear here.",
            bundle: .module,
            comment: "Placeholder text in the menu-bar popover before the run timeline exists.",
        )
    }
}
