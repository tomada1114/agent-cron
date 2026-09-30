import AgentCronCore
import SwiftUI

/// The main window's General section (`docs/product/ux-flows.md` S4): the General screen
/// over `model`, or the placeholder while `App/` hands it none.
struct GeneralSectionView: View {
    let model: GeneralModel?

    var body: some View {
        Group {
            if let model {
                GeneralScreenView(model: model)
            } else {
                SectionPlaceholder(section: .general)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("generalSection")
    }
}

#Preview("Placeholder") {
    GeneralSectionView(model: nil)
}
