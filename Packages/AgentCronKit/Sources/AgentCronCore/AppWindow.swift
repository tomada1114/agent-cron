import Foundation

/// A window of the app shell that something opens by identifier (ADR-0001).
///
/// The app is a menu-bar agent, so no window opens by itself: a command asks SwiftUI's
/// `openWindow(id:)` for one. Declaring the identifier here puts the `Window` scene in
/// `App/` and every view that opens it on one value instead of two matching literals,
/// and keeps the words a person reads about the window in Core's String Catalog.
public enum AppWindow: String, CaseIterable, Sendable {
    /// The one main window: Jobs, History, and General (`docs/product/ux-flows.md`
    /// S2–S4).
    case main

    /// The identifier the window's `Window` scene declares and `openWindow(id:)` asks for.
    public var id: String {
        rawValue
    }

    /// The window's title bar text.
    public var title: LocalizedStringResource {
        switch self {
        case .main:
            LocalizedStringResource(
                "appWindow.main.title",
                defaultValue: "AgentCron",
                bundle: .module,
                comment: "Title of the main window. The app's name.",
            )
        }
    }

    /// What a command that opens this window says.
    public var openCommandTitle: LocalizedStringResource {
        switch self {
        case .main:
            LocalizedStringResource(
                "appWindow.main.open",
                defaultValue: "Open AgentCron…",
                bundle: .module,
                comment: "Button in the menu-bar popover that opens the main window.",
            )
        }
    }
}
