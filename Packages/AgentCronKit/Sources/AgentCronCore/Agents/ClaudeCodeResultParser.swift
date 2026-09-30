import Foundation

/// The fields of Claude Code's JSON result object the parser reads, each decoded on its
/// own so one field of an unexpected type loses only that field.
private struct ResultObject: Decodable {
    private enum CodingKeys: String, CodingKey {
        case durationMilliseconds = "duration_ms"
        case isError = "is_error"
        case result
        case sessionID = "session_id"
        case subtype
        case costUSD = "total_cost_usd"
        case turnCount = "num_turns"
    }

    /// Whether this is a result object at all rather than some other JSON: it carries at
    /// least one of the two fields that say how the run went, `subtype` or `is_error`.
    let isResult: Bool
    let subtype: String?
    /// `is_error`; absent counts as false, since `subtype` then says how the run went.
    let isError: Bool
    let result: String?
    /// Finite or `nil`: a run file stores it, and a `NaN` there would make the file
    /// undecodable. An out-of-range number such as `1e999` never decodes to one.
    let costUSD: Decimal?
    let sessionID: String?
    let durationMilliseconds: Int?
    let turnCount: Int?

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let reportedError = try? container.decodeIfPresent(Bool.self, forKey: .isError)
        subtype = try? container.decodeIfPresent(String.self, forKey: .subtype)
        isResult = subtype != nil || reportedError != nil
        isError = reportedError == true
        result = try? container.decodeIfPresent(String.self, forKey: .result)
        costUSD = (try? container.decodeIfPresent(Decimal.self, forKey: .costUSD))
            .flatMap { cost in cost.isFinite ? cost : nil }
        sessionID = try? container.decodeIfPresent(String.self, forKey: .sessionID)
        durationMilliseconds = try? container.decodeIfPresent(
            Int.self,
            forKey: .durationMilliseconds,
        )
        turnCount = try? container.decodeIfPresent(Int.self, forKey: .turnCount)
    }
}

/// Reads what `claude -p … --output-format json` printed back as a ``RunResult``
/// (ADR-0004).
///
/// The JSON result object is the CLI's, not ours, and a CLI update can change it, so the
/// parser reads only the documented fields — `subtype`, `is_error`, `result`,
/// `total_cost_usd`, `session_id`, `duration_ms`, `num_turns` — ignores the rest, and
/// drops a field of an unexpected type rather than the whole result. Output that is not a
/// result object at all is a failed run with the raw stdout kept as its result text.
public enum ClaudeCodeResultParser {
    /// The `subtype` of a result that finished normally; any other subtype
    /// (`error_max_turns`, `error_during_execution`, …) names an error.
    private static let successSubtype = "success"

    /// What `outcome` says about the run.
    ///
    /// A run succeeds only when the result object reports no error — `is_error` not true,
    /// `subtype` absent or `success` — and the process exited with status 0. A failure's
    /// reason is the error subtype and the first non-blank stderr line, joined by `: `;
    /// with neither, the first line of the result text. It reads only the output and the
    /// exit status: a timeout or a Stop is the dispatcher's to weigh from
    /// ``ProcessOutcome/terminatedBy``.
    public static func parse(_ outcome: ProcessOutcome) -> RunResult {
        let stderrLine = firstLine(of: outcome.stderr)
        guard let object = resultObject(in: outcome.stdout) else {
            let text = nonBlank(text(from: outcome.stdout)) ?? nonBlank(outcome.stderr)
            return RunResult(
                status: .failed,
                resultText: text,
                failureReason: stderrLine ?? text.flatMap(firstLine(of:)),
                report: .empty,
            )
        }

        let errorSubtype = object.subtype.flatMap(nonBlank).flatMap { subtype in
            subtype == successSubtype ? nil : subtype
        }
        let report = RunResult.Report(
            costUSD: object.costUSD,
            sessionID: object.sessionID,
            duration: object.durationMilliseconds.map { .milliseconds($0) },
            turnCount: object.turnCount,
        )
        guard object.isError || errorSubtype != nil || outcome.exitCode != 0 else {
            return RunResult(
                status: .succeeded,
                resultText: object.result,
                failureReason: nil,
                report: report,
            )
        }

        let text = object.result ?? nonBlank(outcome.stderr)
        let reasonParts = [errorSubtype, stderrLine].compactMap(\.self)
        return RunResult(
            status: .failed,
            resultText: text,
            failureReason: reasonParts.isEmpty
                ? text.flatMap(firstLine(of:))
                : reasonParts.joined(separator: ": "),
            report: report,
        )
    }

    /// The result object in `stdout`: the whole output when it decodes as one, otherwise
    /// its last non-blank line — the login shell `ProcessAgentRunner` launches through can
    /// print ahead of it, and `--output-format json` prints the object as one final line.
    private static func resultObject(in stdout: Data) -> ResultObject? {
        if let object = decodeResult(stdout) {
            return object
        }
        let lastLine = text(from: stdout)
            .split(whereSeparator: \.isNewline)
            .last { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return lastLine.flatMap { decodeResult(Data($0.utf8)) }
    }

    private static func decodeResult(_ bytes: Data) -> ResultObject? {
        guard let object = try? JSONDecoder().decode(ResultObject.self, from: bytes),
              object.isResult
        else { return nil }
        return object
    }

    /// The first line of `text` that is not blank, without its surrounding whitespace.
    private static func firstLine(of text: String) -> String? {
        text.split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
    }

    /// `text` unchanged, or `nil` when it holds nothing but whitespace.
    private static func nonBlank(_ text: String) -> String? {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }

    /// `bytes` as UTF-8 text, each invalid sequence replaced by U+FFFD, so stdout that is
    /// not quite UTF-8 is still kept verbatim. Spelled out with `transcode` because
    /// SwiftLint's `optional_data_string_conversion` rejects `String(decoding:as:)`, and
    /// the failable initializer it suggests would drop the whole output instead.
    private static func text(from bytes: Data) -> String {
        var scalars = String.UnicodeScalarView()
        _ = transcode(
            bytes.makeIterator(),
            from: UTF8.self,
            to: UTF32.self,
            stoppingOnError: false,
        ) { scalars.append(Unicode.Scalar($0) ?? "\u{FFFD}") }
        return String(scalars)
    }
}
