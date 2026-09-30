import SwiftUI

/// Shows where a pre-filled value came from, how confident Orev is, and the supporting quote.
struct FieldSourceNote: View {
    let confidence: String
    let evidence: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Pill(text: "From your website", icon: "globe", tint: Palette.teal, fill: Palette.tealSoft)
                Pill(text: "\(confidence.capitalized) confidence", tint: tint, fill: fill)
            }
            if let evidence {
                Text("“\(evidence)”")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(3)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        confidence == "high" ? Palette.sage : confidence == "medium" ? Palette.gold : Palette.coral
    }

    private var fill: Color {
        confidence == "high" ? Palette.sageSoft : confidence == "medium" ? Palette.goldSoft : Palette.coralSoft
    }
}

struct LabeledField: View {
    let label: String
    @Binding var text: String
    var prompt: String = ""
    var keyboard: UIKeyboardType = .default
    var axis: Axis = .horizontal
    var note: FieldSourceNote?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.inkSecondary)
            TextField(prompt.isEmpty ? label : prompt, text: $text, axis: axis)
                .keyboardType(keyboard)
                .lineLimit(axis == .vertical ? 2...5 : 1...1)
                .fieldBackground()
                .accessibilityLabel(label)
            if let note { note }
        }
    }
}
