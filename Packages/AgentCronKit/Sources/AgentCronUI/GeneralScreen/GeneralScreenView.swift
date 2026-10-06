import AgentCronCore
import SwiftUI

/// The General screen (`docs/product/ux-flows.md` S4): Startup, Agents, Keep awake, and
/// History. It renders ``GeneralModel`` and decides nothing; it checks the agent once
/// when it appears (requirements §3.7) and again on Check Again.
struct GeneralScreenView: View {
    let model: GeneralModel

    var body: some View {
        Form {
            startup
            agents
            Section {
                LabeledContent {
                    Text(GeneralScreenText.keepAwakeAlwaysOn)
                        .foregroundStyle(.secondary)
                } label: {
                    Text(GeneralScreenText.keepAwakeWhileRunning)
                }
                .accessibilityIdentifier("keepAwakeInfo")
            } header: {
                Text(GeneralScreenText.keepAwakeHeading)
            }
            Section {
                Text(GeneralScreenText.retention)
                    .accessibilityIdentifier("retentionInfo")
            } header: {
                Text(GeneralScreenText.historyHeading)
            }
        }
        .formStyle(.grouped)
        .task {
            model.refreshLoginItemStatus()
            await model.checkAgain()
        }
    }

    private var startup: some View {
        Section {
            Toggle(isOn: Binding(
                get: { model.isLaunchAtLoginOn },
                set: { model.setLaunchAtLogin($0) },
            )) {
                Text(GeneralScreenText.launchAtLogin)
            }
            .toggleStyle(.switch)
            .accessibilityIdentifier("launchAtLoginToggle")
            if let note = model.loginItemNote {
                HStack(spacing: DesignLock.spacingS) {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: DesignLock.spacingS)
                    if model.showsOpenLoginItems {
                        Button {
                            model.openLoginItems()
                        } label: {
                            Text(GeneralScreenText.openLoginItems)
                        }
                        .accessibilityIdentifier("openLoginItemsButton")
                    }
                }
            }
        } header: {
            Text(GeneralScreenText.startupHeading)
        }
    }

    private var agents: some View {
        Section {
            LabeledContent {
                HStack(alignment: .firstTextBaseline, spacing: DesignLock.spacingS) {
                    // The status takes the width the row has free; the spacer only fills
                    // what is left, so the path and version are not truncated.
                    agentStatus
                        .layoutPriority(1)
                    Spacer(minLength: DesignLock.spacingS)
                    if model.showsSpinner {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel(Text(GeneralScreenText.checking))
                            .accessibilityIdentifier("agentCheckSpinner")
                    }
                    Button {
                        Task { await model.checkAgain() }
                    } label: {
                        Text(GeneralScreenText.checkAgain)
                    }
                    .disabled(model.isChecking)
                    .accessibilityIdentifier("checkAgainButton")
                }
            } label: {
                Text(GeneralScreenText.claudeCode)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("claudeCodeRow")
        } header: {
            Text(GeneralScreenText.agentsHeading)
        }
    }

    private var agentStatus: some View {
        VStack(alignment: .leading, spacing: DesignLock.spacingXS) {
            switch model.agent {
            case let .available(path, version):
                availableLabel(path: path, version: version)

            case .notFound, .error:
                if let headline = GeneralModel.agentHeadline(for: model.agent) {
                    Label {
                        Text(headline)
                    } icon: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }

            case .none:
                EmptyView()
            }
            if let detail = GeneralModel.agentDetail(for: model.agent) {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func availableLabel(path: String, version: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: DesignLock.spacingXS) {
                Text(verbatim: path)
                    .fixedSize(horizontal: false, vertical: true)
                if !version.isEmpty {
                    Text(verbatim: version)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .textSelection(.enabled)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }
}
