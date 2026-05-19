import SwiftUI

struct RevenueImpactCard: View {
    @Environment(AppState.self) private var appState
    @State private var selectedPeriod: RevenuePeriod = .daily

    enum RevenuePeriod: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"

        var multiplier: Double {
            switch self {
            case .daily: return 1
            case .weekly: return 7
            case .monthly: return 30
            }
        }
    }

    private var currentRevenue: Double {
        appState.dailyCurrentRevenue * selectedPeriod.multiplier
    }

    private var optimalRevenue: Double {
        appState.dailyOptimalRevenue * selectedPeriod.multiplier
    }

    private var missedRevenue: Double {
        optimalRevenue - currentRevenue
    }

    private var revenueRatio: Double {
        guard optimalRevenue > 0 else { return 1.0 }
        return min(currentRevenue / optimalRevenue, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.subheadline)
                        .foregroundStyle(RevOwlTheme.gold)
                    Text("Revenue Impact")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                Spacer()
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(RevenuePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Revenue")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currentRevenue, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(missedRevenue > 0 ? "Potential Missed" : "Revenue Optimized")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: missedRevenue > 0 ? "arrow.down.right" : "checkmark.circle.fill")
                            .font(.caption)
                        Text(abs(missedRevenue), format: .currency(code: "USD").precision(.fractionLength(0)))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(missedRevenue > 0 ? RevOwlTheme.negative : RevOwlTheme.positive)
                }
            }

            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [RevOwlTheme.gold.opacity(0.6), RevOwlTheme.gold],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * revenueRatio)
                            .shadow(color: RevOwlTheme.gold.opacity(0.3), radius: 4)
                            .animation(.snappy, value: revenueRatio)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("Earning")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Optimal (\(optimalRevenue, format: .currency(code: "USD").precision(.fractionLength(0))))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if missedRevenue > 50 {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Apply \(appState.pendingRecommendationCount) pending dynamic rates to capture this revenue.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08), in: .rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.orange.opacity(0.15), lineWidth: 0.5)
                )
            }
        }
        .padding(16)
        .glassCardStyle()
    }
}
