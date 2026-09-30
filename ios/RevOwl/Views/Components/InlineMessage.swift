import SwiftUI

struct InlineMessage: View {
    enum Kind { case error, info, warning, success }

    let kind: Kind
    let text: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.body.weight(.semibold))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(minHeight: 32)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(fill, in: .rect(cornerRadius: Metrics.smallRadius))
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch kind {
        case .error: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.circle.fill"
        case .success: "checkmark.circle.fill"
        }
    }

    private var tint: Color {
        switch kind {
        case .error: Palette.coral
        case .info: Palette.teal
        case .warning: Palette.gold
        case .success: Palette.sage
        }
    }

    private var fill: Color {
        switch kind {
        case .error: Palette.coralSoft
        case .info: Palette.tealSoft
        case .warning: Palette.goldSoft
        case .success: Palette.sageSoft
        }
    }
}
