import SwiftUI

/// The design lock's layout tokens (ADR-0009), named once so every screen reads the same
/// value instead of repeating a literal.
public enum DesignLock {
    /// Spacing inside a row.
    public static let spacingXS: CGFloat = 4
    /// Spacing between related controls.
    public static let spacingS: CGFloat = 8
    /// Spacing between groups and between popover sections.
    public static let spacingM: CGFloat = 16
    /// Content-to-edge spacing in detail panes.
    public static let spacingL: CGFloat = 24
    /// The popover's inner padding (8 + 4).
    public static let popoverPadding: CGFloat = 12
    /// The height of a popover row.
    public static let popoverRowHeight: CGFloat = 28
    /// The corner radius of weekday chips, the popover banner, and the bypass badge.
    public static let chipCornerRadius: CGFloat = 6
    /// The main window's minimum width.
    public static let mainWindowMinWidth: CGFloat = 860
    /// The main window's minimum height.
    public static let mainWindowMinHeight: CGFloat = 560
    /// The main window's default width.
    public static let mainWindowDefaultWidth: CGFloat = 1_040
    /// The main window's default height.
    public static let mainWindowDefaultHeight: CGFloat = 680
    /// The popover's width.
    public static let popoverWidth: CGFloat = 340
    /// The popover's maximum height; below it, the popover sizes to its content.
    public static let popoverMaxHeight: CGFloat = 520
}

extension Color {
    /// `RunningTint` from AgentCronUI's own asset catalog: a package view cannot see
    /// `App/Assets.xcassets`.
    static let runningTint = Color("RunningTint", bundle: .module)
}
