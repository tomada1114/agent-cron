/// What started a run.
///
/// The raw value is what a run file stores, so changing it is a file-format change.
public enum RunTrigger: String, Sendable, Codable, CaseIterable {
    /// A scheduled time was missed (asleep, or the app was not running) and the run
    /// happened on wake or launch instead, within the catch-up window.
    case catchUp = "catch_up"
    /// The user chose Run Now.
    case manual
    /// The job's schedule reached one of its times while the app was running.
    case scheduled
}
