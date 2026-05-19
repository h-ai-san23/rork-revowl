import SwiftUI

struct DemandDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                DemandGaugeView(score: appState.demandScore, size: 140)
                    .padding(.top, 8)

                VStack(spacing: 4) {
                    Text("Aggregate Demand Score")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Based on \(appState.demandSignals.count) active signals")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("What this means")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(demandExplanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCardStyle(cornerRadius: 14, elevation: .subtle)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Signal Breakdown")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    ForEach(appState.demandSignals) { signal in
                        HStack(spacing: 12) {
                            Image(systemName: signal.source.icon)
                                .font(.title3)
                                .foregroundStyle(RevOwlTheme.demandColor(for: signal.score))
                                .frame(width: 40, height: 40)
                                .background(RevOwlTheme.demandColor(for: signal.score).opacity(0.12), in: .rect(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(signal.source.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Text("\(signal.score)")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(RevOwlTheme.demandColor(for: signal.score))
                                        Text("/100")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                Text(signal.details)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(2)

                                HStack(spacing: 4) {
                                    Image(systemName: "link")
                                        .font(.system(size: 8))
                                    Text(apiSourceLabel(for: signal.source))
                                        .font(.caption2)
                                }
                                .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(14)
                        .glassCardStyle(cornerRadius: 16, elevation: .subtle)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Data Sources")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    VStack(spacing: 0) {
                        sourceRow(icon: "airplane.arrival", name: "Airport Arrivals", source: "FlightAware / AeroDataBox API")
                        sourceDivider
                        sourceRow(icon: "ferry.fill", name: "Cruise Port", source: "CruiseMapper API")
                        sourceDivider
                        sourceRow(icon: "ticket.fill", name: "Local Events", source: "Perplexity Sonar Web Search")
                        sourceDivider
                        sourceRow(icon: "car.fill", name: "Traffic", source: "Google Maps Roads API")
                        sourceDivider
                        sourceRow(icon: "building.2.fill", name: "Competitor Avail.", source: "Xotelo / Makcorps API")
                        sourceDivider
                        sourceRow(icon: "cloud.sun.fill", name: "Weather", source: "OpenWeather API")
                        sourceDivider
                        sourceRow(icon: "calendar", name: "Seasonality", source: "ML Historical Patterns")
                    }
                    .glassCardStyle(cornerRadius: 14, elevation: .subtle)
                }
            }
            .padding(20)
        }
        .navigationTitle("Demand Score")
        .navigationBarTitleDisplayMode(.inline)
        .deepGlassBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(RevOwlTheme.gold)
            }
        }
    }

    private var demandExplanation: String {
        let score = appState.demandScore
        if score >= 70 {
            return "High demand detected. Multiple signals indicate strong travel activity in your area. Airport arrivals are elevated, local events are driving bookings, and competitor availability is tightening. This is an ideal time to optimize rates upward."
        } else if score >= 40 {
            return "Moderate demand. Some positive signals detected but the market isn't under significant pressure. Monitor competitor moves and be ready to adjust if conditions strengthen."
        } else {
            return "Low demand period. Consider competitive pricing to capture available bookings. Focus on volume over rate optimization."
        }
    }

    private func apiSourceLabel(for source: DemandSource) -> String {
        switch source {
        case .airport: return "via FlightAware API"
        case .cruisePort: return "via CruiseMapper API"
        case .localEvents: return "via Perplexity Sonar Web Search"
        case .traffic: return "via Google Maps Roads API"
        case .competitorAvailability: return "via OTA Monitoring"
        case .weather: return "via OpenWeather API"
        case .seasonality: return "via ML Historical Analysis"
        }
    }

    private func sourceRow(icon: String, name: String, source: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(RevOwlTheme.gold)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                Text(source)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var sourceDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.04))
            .frame(height: 0.5)
            .padding(.leading, 48)
    }
}
