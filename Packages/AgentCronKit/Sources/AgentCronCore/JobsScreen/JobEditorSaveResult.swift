/// What ``JobEditorModel/save()`` did.
public enum JobEditorSaveResult: Sendable, Equatable {
    /// The store could not be read or written, so nothing was saved — including when the
    /// saved jobs could not be read, which a save must never overwrite.
    case failed(StorageError)
    /// A field breaks a rule, so nothing was written; `firstField` is the first one in
    /// editor order, where focus moves.
    case invalid(firstField: JobEditorField)
    /// The job was written to the store.
    case saved
}
