/// What one run asks the agent to do, in no agent's vocabulary (ADR-0004).
///
/// The dispatcher builds it from the run's ``JobSnapshot``; the ``AgentCommandBuilding``
/// its ``AgentKind`` names turns it into a command line. The working directory and the
/// timeout are not here: they go to ``AgentRunning`` beside the command line, not into it.
public struct RunRequest: Sendable, Equatable {
    /// The prompt, exactly as typed — one argument however many lines it has.
    public let prompt: String
    /// The model to ask for; ``ModelChoice/default`` passes none.
    public let model: ModelChoice
    /// The effort to ask for; ``EffortChoice/default`` passes none.
    public let effort: EffortChoice
    /// What the agent may do without asking.
    public let permissionMode: PermissionMode

    /// Makes a request from its parts.
    public init(
        prompt: String,
        model: ModelChoice,
        effort: EffortChoice,
        permissionMode: PermissionMode,
    ) {
        self.prompt = prompt
        self.model = model
        self.effort = effort
        self.permissionMode = permissionMode
    }

    /// The request a run of `snapshot` makes — what the saved job asked for when the run
    /// started, so an edit made while it runs changes nothing.
    public init(_ snapshot: JobSnapshot) {
        self.init(
            prompt: snapshot.prompt,
            model: snapshot.model,
            effort: snapshot.effort,
            permissionMode: snapshot.permissionMode,
        )
    }
}
