import SwiftUI

/// Opaque, readable content surface. Content never sits on glass.
struct CardStyle: ViewModifier {
    var padding: CGFloat
    var fill: Color

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: .rect(cornerRadius: Metrics.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cardRadius)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
            }
    }
}

extension View {
    func card(padding: CGFloat = 16, fill: Color = Palette.surface) -> some View {
        modifier(CardStyle(padding: padding, fill: fill))
    }

    func fieldBackground() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(Palette.surfaceRaised, in: .rect(cornerRadius: Metrics.smallRadius))
    }
}
