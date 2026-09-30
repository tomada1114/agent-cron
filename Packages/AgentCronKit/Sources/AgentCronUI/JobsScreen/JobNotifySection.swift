import AgentCronCore
import SwiftUI

/// The editor's Notifications section: Notify, and the notifications-off note while the
/// user has turned them off (`docs/design/ux-guidelines.md` › States).
struct JobNotifySection: View {
    /// System Settings › Notifications, where the user turns this app's notifications
    /// back on.
    private static let notificationSettings =
        URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")

    let editor: JobEditorModel
    let authorization: NotificationAuthorizationState?

    @Environment(\.openURL)
    private var openURL

    var body: some View {
        Section {
            Picker(selection: Binding(
                get: { editor.draft.notify },
                set: { editor.notifyChosen($0) },
            )) {
                ForEach(NotifyPolicy.allCases, id: \.self) { policy in
                    Text(policy.title).tag(policy)
                }
            } label: {
                Text(JobsScreenText.notifyLabel)
            }
            .accessibilityIdentifier("notifyPicker")
            if let note = editor.notificationsOffNote(authorization: authorization) {
                notificationsOff(note)
            }
        } header: {
            Text(JobsScreenText.notificationsSection)
                .font(.headline)
        }
    }

    private func notificationsOff(_ note: LocalizedStringResource) -> some View {
        HStack(spacing: DesignLock.spacingS) {
            Label {
                Text(note)
            } icon: {
                Image(systemName: "bell.slash")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            Spacer(minLength: DesignLock.spacingS)
            if let url = Self.notificationSettings {
                Button {
                    openURL(url)
                } label: {
                    Text(JobsScreenText.openSystemSettings)
                }
                .accessibilityIdentifier("openNotificationSettingsButton")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("notificationsOffNote")
    }
}
