import SwiftUI

/// A selectable hotel row used for listing confirmation and competitor picking.
struct HotelCandidateRow: View {
    let hotel: HotelCandidate
    let currency: String
    var badge: String?
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(isSelected ? Palette.teal : Palette.surfaceRaised)
                    if let badge, isSelected {
                        Text(badge).font(.subheadline.weight(.bold)).foregroundStyle(Palette.onAccent)
                    } else {
                        Image(systemName: isSelected ? "checkmark" : "plus")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(isSelected ? Palette.onAccent : Palette.inkSecondary)
                    }
                }
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(hotel.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 8) {
                        if let d = hotel.distanceKm {
                            Label(d < 1 ? "\(Int(d * 1000)) m" : String(format: "%.1f km", d), systemImage: "location")
                        }
                        if let r = hotel.rating {
                            Label(String(format: "%.1f", r), systemImage: "star")
                        }
                        if let min = hotel.priceMin, let max = hotel.priceMax {
                            Text("Listed \(Fmt.money(min, currency))–\(Fmt.money(max, currency))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Palette.inkTertiary)
                    .labelStyle(.titleAndIcon)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
