import SwiftUI
import MapKit

struct CompetitorMapView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedCompetitorId: String?
    @State private var selectedCompetitor: Competitor?

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition, selection: $selectedCompetitorId) {
                Annotation("Your Hotel", coordinate: CLLocationCoordinate2D(
                    latitude: appState.hotel.latitude == 0 ? 25.7617 : appState.hotel.latitude,
                    longitude: appState.hotel.longitude == 0 ? -80.1918 : appState.hotel.longitude
                )) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(RevOwlTheme.gold.opacity(0.2))
                                .frame(width: 52, height: 52)
                            Circle()
                                .fill(RevOwlTheme.gold.opacity(0.35))
                                .frame(width: 40, height: 40)
                            Image(systemName: "building.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(RevOwlTheme.gold, in: .circle)
                                .shadow(color: RevOwlTheme.gold.opacity(0.5), radius: 6)
                        }
                        Text("Your Hotel")
                            .font(.caption2.bold())
                            .foregroundStyle(RevOwlTheme.gold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: .capsule)
                    }
                }

                ForEach(appState.competitors) { competitor in
                    Annotation(competitor.name, coordinate: CLLocationCoordinate2D(
                        latitude: competitor.latitude,
                        longitude: competitor.longitude
                    )) {
                        Button {
                            withAnimation(.snappy) {
                                selectedCompetitor = competitor
                                selectedCompetitorId = competitor.id
                            }
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(selectedCompetitorId == competitor.id ? RevOwlTheme.gold.opacity(0.2) : Color.blue.opacity(0.15))
                                        .frame(width: 46, height: 46)
                                    Circle()
                                        .fill(selectedCompetitorId == competitor.id ? RevOwlTheme.gold.opacity(0.3) : Color.blue.opacity(0.25))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "bed.double.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 28, height: 28)
                                        .background(
                                            selectedCompetitorId == competitor.id ? RevOwlTheme.gold : Color.blue,
                                            in: .circle
                                        )
                                        .shadow(color: (selectedCompetitorId == competitor.id ? RevOwlTheme.gold : Color.blue).opacity(0.4), radius: 4)
                                }
                                Text(competitor.currentRate, format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        selectedCompetitorId == competitor.id ? RevOwlTheme.gold : .white,
                                        in: .capsule
                                    )
                                    .foregroundStyle(selectedCompetitorId == competitor.id ? .white : RevOwlTheme.navy)
                            }
                        }
                    }
                    .tag(competitor.id)
                }
            }
            .mapStyle(.standard(elevation: .realistic))

            if let competitor = selectedCompetitor {
                mapDetailCard(competitor)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Competitor Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(RevOwlTheme.gold)
            }
        }
        .onChange(of: selectedCompetitorId) { _, newValue in
            if let id = newValue {
                withAnimation(.snappy) {
                    selectedCompetitor = appState.competitors.first(where: { $0.id == id })
                }
            } else {
                withAnimation(.snappy) {
                    selectedCompetitor = nil
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: selectedCompetitorId)
    }

    private func mapDetailCard(_ competitor: Competitor) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            VStack(spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(competitor.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        HStack(spacing: 6) {
                            HStack(spacing: 1) {
                                ForEach(0..<competitor.stars, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(RevOwlTheme.gold)
                                }
                            }
                            Text("•")
                                .foregroundStyle(.tertiary)
                            Text(String(format: "%.1f mi away", competitor.distance))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(competitor.currentRate, format: .currency(code: "USD").precision(.fractionLength(0)))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        HStack(spacing: 2) {
                            Image(systemName: competitor.rateChange > 0 ? "arrow.up.right" : competitor.rateChange < 0 ? "arrow.down.right" : "minus")
                                .font(.caption2)
                            Text(String(format: "%+.1f%%", competitor.rateChange))
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(competitor.rateChange > 0 ? RevOwlTheme.negative : competitor.rateChange < 0 ? RevOwlTheme.positive : .secondary)
                    }
                }

                HStack(spacing: 8) {
                    availabilityBadge(competitor.availability)
                    Spacer()
                    Text("Today, 1 night")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if !competitor.otaRates.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(competitor.otaRates) { ota in
                            HStack {
                                Text(ota.otaName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(ota.rate, format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            if ota.id != competitor.otaRates.last?.id {
                                Rectangle()
                                    .fill(Color.primary.opacity(0.05))
                                    .frame(height: 0.5)
                                    .padding(.leading, 12)
                            }
                        }
                    }
                    .background(Color.primary.opacity(0.03), in: .rect(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
                }

                Button {
                    withAnimation(.snappy) {
                        selectedCompetitor = nil
                        selectedCompetitorId = nil
                    }
                } label: {
                    Text("Dismiss")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(.regularMaterial, in: .rect(cornerRadii: .init(topLeading: 20, topTrailing: 20)))
        .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
    }

    private func availabilityBadge(_ status: String) -> some View {
        let color: Color = {
            switch status {
            case "Sold Out": return RevOwlTheme.negative
            case "Limited": return .orange
            default: return RevOwlTheme.positive
            }
        }()

        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.5), radius: 3)
            Text(status)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: .capsule)
    }
}
