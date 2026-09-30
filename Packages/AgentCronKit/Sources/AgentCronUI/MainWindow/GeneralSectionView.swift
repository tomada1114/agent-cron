import AgentCronCore
import SwiftUI

/// The main window's General section (`docs/product/ux-flows.md` S4) — a placeholder until
/// the settings (#25) replace it.
struct GeneralSectionView: View {
    var body: some View {
        SectionPlaceholder(section: .general)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("generalSection")
    }
}

#Preview("Placeholder") {
    GeneralSectionView()
}
