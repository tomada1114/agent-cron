import AgentCronCore
import SwiftUI

/// The status item's label (ADR-0009): the model's symbol, with a red dot while an unseen
/// failure exists. Under Reduce Motion the running symbol is already the static filled
/// variant, so nothing here animates.
public struct StatusItemLabel: View {
    private static let dotSize: CGFloat = 6

    private let model: PopoverModel

    public var body: some View {
        Image(systemName: model.statusSymbol.symbolName)
            .overlay(alignment: .topTrailing) {
                if model.showsFailureDot {
                    Circle()
                        .fill(Color.red)
                        .frame(width: Self.dotSize, height: Self.dotSize)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel(Text(verbatim: "AgentCron"))
            .accessibilityIdentifier("statusItemLabel")
    }

    /// Creates the label over the popover's model.
    public init(model: PopoverModel) {
        self.model = model
    }
}
