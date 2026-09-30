import Foundation

/// Where the app keeps its files (ADR-0005).
public enum StorageLocation {
    /// The folder ``FileJobStore`` and ``FileRunStore`` share:
    /// `<Application Support>/io.github.tomada1114.AgentCron/`.
    ///
    /// Named for the bundle identifier, which ``AppLog/subsystem`` already spells (and
    /// `AppLogTests` holds to `project.yml`), so a renamed app moves its folder with it.
    /// Unsandboxed (ADR-0002), Application Support is the user's own
    /// `~/Library/Application Support`. Nothing is created here; the first save does that.
    /// - Parameter applicationSupport: The Application Support folder; a test passes its
    ///   own so it never touches the real one.
    public static func root(
        inApplicationSupport applicationSupport: URL = .applicationSupportDirectory,
    ) -> URL {
        applicationSupport.appending(path: AppLog.subsystem, directoryHint: .isDirectory)
    }
}
