import AgentCronCore
import AppKit
import SwiftUI

/// What follows the fields: the result with [Raw] and [Copy], a skipped run's reason, or
/// a running run's Stop and note.
struct HistoryRunBodyView: View {
    let detail: HistoryRunDetail
    let stop: (() -> Void)?
    @State private var showsRaw = false

    var body: some View {
        switch detail.body {
        case .running:
            VStack(alignment: .leading, spacing: DesignLock.spacingS) {
                Button {
                    stop?()
                } label: {
                    Label {
                        Text(HistoryScreenText.stop)
                    } icon: {
                        Image(systemName: "stop.fill")
                    }
                }
                .disabled(stop == nil)
                .accessibilityIdentifier("historyStopButton")
                Text(HistoryScreenText.resultPending)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("historyResultPending")
            }

        case let .skipped(reason):
            VStack(alignment: .leading, spacing: DesignLock.spacingXS) {
                Text(HistoryScreenText.reason)
                    .font(.headline)
                if let reason {
                    Text(reason.title)
                        .accessibilityIdentifier("historySkipReason")
                }
            }

        case let .output(text):
            VStack(alignment: .leading, spacing: DesignLock.spacingS) {
                resultHeader(text: text)
                if showsRaw {
                    Text(verbatim: text)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("historyRawResult")
                } else {
                    MarkdownResultView(text: text)
                }
            }

        case .noOutput:
            VStack(alignment: .leading, spacing: DesignLock.spacingS) {
                Text(HistoryScreenText.result)
                    .font(.headline)
                Text(HistoryScreenText.noResult)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func resultHeader(text: String) -> some View {
        HStack(spacing: DesignLock.spacingS) {
            Text(HistoryScreenText.result)
                .font(.headline)
            Spacer()
            Toggle(isOn: $showsRaw) {
                Text(HistoryScreenText.raw)
            }
            .toggleStyle(.button)
            .accessibilityIdentifier("historyRawToggle")
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            } label: {
                Label {
                    Text(HistoryScreenText.copy)
                } icon: {
                    Image(systemName: "doc.on.doc")
                }
            }
            .accessibilityIdentifier("historyCopyButton")
        }
    }
}
