import AgentCronCore
import SwiftUI

/// The failure and agent-not-found banners above the timeline.
struct PopoverBanners: View {
    private static let bannerTintOpacity = 0.12

    let model: PopoverModel
    let actions: PopoverActions

    var body: some View {
        if model.unseenFailureCount > 0 {
            banner(
                PopoverText.failureBanner(count: model.unseenFailureCount),
                button: PopoverText.view,
                identifier: "popoverFailureBanner",
            ) {
                actions.open(.history)
            }
        }
        if model.isAgentMissing {
            banner(
                PopoverBanner.agentNotFound,
                button: PopoverText.openGeneral,
                identifier: "popoverAgentBanner",
            ) {
                actions.open(.general)
            }
        }
    }

    private func banner(
        _ message: LocalizedStringResource,
        button: LocalizedStringResource,
        identifier: String,
        action: @escaping () -> Void,
    ) -> some View {
        HStack(spacing: DesignLock.spacingS) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: DesignLock.spacingXS)
            Button(button, action: action)
                .accessibilityIdentifier("\(identifier).button")
        }
        .padding(DesignLock.spacingS)
        .background(
            .red.opacity(Self.bannerTintOpacity),
            in: RoundedRectangle(cornerRadius: DesignLock.chipCornerRadius),
        )
        .padding([.horizontal, .top], DesignLock.popoverPadding)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}
