import SwiftUI

/// Orev with a headline and message. Stacks vertically at accessibility text sizes.
struct OrevBubble: View {
    let state: OrevState
    let title: String
    var message: String?
    var size: CGFloat = 78

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            OrevView(state: state, size: size)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.display(.title2))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let message {
                    Text(message)
                        .font(.body)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
