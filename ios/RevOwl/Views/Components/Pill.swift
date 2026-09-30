import SwiftUI

struct Pill: View {
    let text: String
    var icon: String?
    var tint: Color = Palette.teal
    var fill: Color = Palette.tealSoft

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).imageScale(.small)
            }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(fill, in: .capsule)
    }
}

/// Labels a number with where it comes from: actual, on the books, public rates, sample…
struct BasisBadge: View {
    let basis: String

    var body: some View {
        Pill(text: label, icon: icon, tint: colors.0, fill: colors.1)
            .accessibilityLabel("Source: \(label)")
    }

    private var label: String {
        switch basis {
        case "actual": "Actual"
        case "on_the_books": "On the books"
        case "forecast": "Forecast"
        case "market": "Public rates · Beta"
        case "event": "Event"
        case "sample": "Sample data"
        case "assumption": "Assumption"
        default: basis.capitalized
        }
    }

    private var icon: String? {
        switch basis {
        case "sample": "flask"
        case "market": "globe"
        case "on_the_books": "book.closed"
        default: nil
        }
    }

    private var colors: (Color, Color) {
        switch basis {
        case "actual": (Palette.sage, Palette.sageSoft)
        case "on_the_books": (Palette.teal, Palette.tealSoft)
        case "forecast", "market": (Palette.gold, Palette.goldSoft)
        case "sample": (Palette.coral, Palette.coralSoft)
        default: (Palette.inkSecondary, Palette.surfaceRaised)
        }
    }
}
