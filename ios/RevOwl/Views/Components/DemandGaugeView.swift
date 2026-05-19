import SwiftUI

struct DemandGaugeView: View {
    let score: Int
    let size: CGFloat

    private var color: Color { RevOwlTheme.demandColor(for: score) }
    private var progress: Double { Double(score) / 100.0 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.1), lineWidth: size * 0.08)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.2), color, color],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * progress)
                    ),
                    style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.4), radius: size * 0.06)

            Circle()
                .fill(.thinMaterial)
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.08), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: size * 0.3
                            )
                        )
                )
                .overlay(
                    Circle()
                        .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
                )
                .frame(width: size * 0.7, height: size * 0.7)

            VStack(spacing: 1) {
                Text("\(score)")
                    .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                if size > 50 {
                    Text("Demand")
                        .font(.system(size: size * 0.1, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

struct OccupancyRingView: View {
    let sold: Int
    let total: Int
    let size: CGFloat

    private var rate: Double {
        guard total > 0 else { return 0 }
        return Double(sold) / Double(total)
    }
    private var color: Color { RevOwlTheme.occupancyColor(for: rate) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.1), lineWidth: size * 0.08)

            Circle()
                .trim(from: 0, to: rate)
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.3), radius: size * 0.04)

            Circle()
                .fill(.thinMaterial)
                .overlay(
                    Circle()
                        .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
                )
                .frame(width: size * 0.7, height: size * 0.7)

            VStack(spacing: 1) {
                Text("\(sold)/\(total)")
                    .font(.system(size: size * 0.16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("\(Int(rate * 100))%")
                    .font(.system(size: size * 0.11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

struct StatCardView: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCardStyle(cornerRadius: 20)
    }
}
