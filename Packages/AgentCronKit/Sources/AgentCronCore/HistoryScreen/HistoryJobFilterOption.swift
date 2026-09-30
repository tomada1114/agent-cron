import Foundation

/// A job the History job filter offers.
public struct HistoryJobFilterOption: Sendable, Identifiable {
    /// The job's identifier.
    public let id: UUID
    /// The job's current name, or the name its latest run recorded once it is deleted.
    public let name: String
    /// Whether the job no longer exists; its runs stay in history.
    public let isDeleted: Bool

    /// The option's label: the name, with "(deleted)" after a deleted job's.
    public var title: LocalizedStringResource {
        if isDeleted {
            LocalizedStringResource(
                "history.jobFilter.deleted",
                defaultValue: "\(name) (deleted)",
                bundle: .module,
                comment: "History job filter option for a deleted job. The argument is its name.",
            )
        } else {
            LocalizedStringResource(
                "history.jobFilter.job",
                defaultValue: "\(name)",
                bundle: .module,
                comment: "History job filter option for an existing job. The argument is its name.",
            )
        }
    }

    /// An option for the job `id`, named `name`.
    public init(id: UUID, name: String, isDeleted: Bool) {
        self.id = id
        self.name = name
        self.isDeleted = isDeleted
    }
}
