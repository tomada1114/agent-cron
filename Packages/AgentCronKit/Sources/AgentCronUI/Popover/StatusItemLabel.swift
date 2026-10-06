import AgentCronCore
import AppKit
import SwiftUI

/// The status item's label (ADR-0009): the model's symbol, with a red dot while an unseen
/// failure exists. Under Reduce Motion the running symbol is already the static filled
/// variant, so nothing here animates.
public struct StatusItemLabel: View {
    private static let dotSize: CGFloat = 6

    private let model: PopoverModel

    public var body: some View {
        symbolImage
            .accessibilityIdentifier("statusItemLabel")
    }

    /// The menu bar draws a `MenuBarExtra` label as a template image, which flattens a
    /// SwiftUI overlay away; the dot therefore has to be baked into one non-template image.
    @ViewBuilder private var symbolImage: some View {
        let name = model.statusSymbol.symbolName
        if model.showsFailureDot, let image = Self.dottedImage(symbolName: name) {
            Image(nsImage: image)
                .accessibilityLabel(Text(verbatim: "AgentCron"))
        } else {
            Image(systemName: name)
                .accessibilityLabel(Text(verbatim: "AgentCron"))
        }
    }

    /// Creates the label over the popover's model.
    public init(model: PopoverModel) {
        self.model = model
    }

    /// Draws the symbol in `labelColor` and a red dot at its top-trailing corner. The
    /// drawing handler runs at draw time under the menu bar's appearance, so the symbol
    /// still reads in a light and a dark menu bar even though the image is not a template.
    private static func dottedImage(symbolName: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(textStyle: .body, scale: .large)
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        else {
            return nil
        }
        let size = symbol.size
        let image = NSImage(size: size, flipped: false) { rect in
            let tinted = NSImage(size: size, flipped: false) { inner in
                symbol.draw(in: inner)
                NSColor.labelColor.set()
                inner.fill(using: .sourceAtop)
                return true
            }
            tinted.draw(in: rect)
            let dot = NSRect(
                x: rect.maxX - dotSize,
                y: rect.maxY - dotSize,
                width: dotSize,
                height: dotSize,
            )
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
