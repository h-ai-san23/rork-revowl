import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Palette.teal

    func makeBody(configuration: Configuration) -> some View {
        StyledButtonBody(configuration: configuration, fill: tint, foreground: Palette.onAccent, border: .clear)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledButtonBody(configuration: configuration, fill: Palette.surfaceRaised, foreground: Palette.ink, border: Palette.hairline)
    }
}

private struct StyledButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let fill: Color
    let foreground: Color
    let border: Color
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(fill.opacity(isEnabled ? 1 : 0.4), in: .capsule)
            .overlay { Capsule().strokeBorder(border, lineWidth: 1) }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.22), value: configuration.isPressed)
    }
}

/// Selectable chip used for goals, follow-ups and filters.
struct ChipButtonStyle: ButtonStyle {
    var isSelected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? Palette.onAccent : Palette.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(isSelected ? Palette.teal : Palette.surfaceRaised, in: .capsule)
            .overlay { Capsule().strokeBorder(isSelected ? Color.clear : Palette.hairline, lineWidth: 1) }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
