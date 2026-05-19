import SwiftUI

struct RecommendationsView: View {
    @Environment(AppState.self) private var appState
    @State private var filter: RecommendationStatus? = .pending
    @State private var animateAppear = false

    private var filteredRecommendations: [Recommendation] {
        guard let filter else { return appState.recommendations }
        return appState.recommendations.filter { $0.status == filter }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                dynamicPricingHeader
                filterBar

                if filteredRecommendations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "brain")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("No Dynamic Rates")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("RevOwl is analyzing the market.\nTap Recalculate to generate recommendations.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            appState.regenerateRecommendations()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Generate Recommendations")
                            }
                        }
                        .buttonStyle(GoldButtonStyle())
                        .padding(.horizontal, 40)
                        .sensoryFeedback(.impact(weight: .medium), trigger: appState.recommendations.count)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(Array(filteredRecommendations.enumerated()), id: \.element.id) { index, rec in
                        RecommendationCard(recommendation: rec) {
                            withAnimation(.snappy) { appState.applyRecommendation(rec.id) }
                        } onDismiss: {
                            withAnimation(.snappy) { appState.dismissRecommendation(rec.id) }
                        }
                        .staggeredAppear(index: index, appear: animateAppear)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("Dynamic Rates")
        .deepGlassBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.regenerateRecommendations()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Recalculate")
                    }
                    .font(.caption.weight(.medium))
                }
                .foregroundStyle(RevOwlTheme.gold)
                .sensoryFeedback(.impact(weight: .medium), trigger: appState.recommendations.count)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateAppear = true
            }
        }
        .sensoryFeedback(.selection, trigger: filter)
    }

    private var dynamicPricingHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.fill")
                .font(.title2)
                .foregroundStyle(.purple)
                .shadow(color: .purple.opacity(0.4), radius: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Dynamic Pricing")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Rates optimized using competitor data, demand signals, and occupancy in real-time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .glassCardStyle(cornerRadius: 16, elevation: .subtle)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("All") { filter = nil }
                    .buttonStyle(GlassChipStyle(isActive: filter == nil))
                Button("Pending") { filter = .pending }
                    .buttonStyle(GlassChipStyle(isActive: filter == .pending))
                Button("Applied") { filter = .applied }
                    .buttonStyle(GlassChipStyle(isActive: filter == .applied))
                Button("Dismissed") { filter = .dismissed }
                    .buttonStyle(GlassChipStyle(isActive: filter == .dismissed))
            }
        }
        .contentMargins(.horizontal, 0)
    }
}

struct RecommendationCard: View {
    let recommendation: Recommendation
    let onApply: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(recommendation.roomTypeName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        confidenceBadge
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                        Text(recommendation.dateRange)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.purple)
                    }
                }
                Spacer()
                statusBadge
            }

            HStack(alignment: .center, spacing: 16) {
                VStack(spacing: 2) {
                    Text("Current")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(recommendation.currentRate, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.title3)
                        .foregroundStyle(.primary.opacity(0.8))
                }

                Image(systemName: "arrow.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(RevOwlTheme.gold)
                    .shadow(color: RevOwlTheme.gold.opacity(0.4), radius: 4)

                VStack(spacing: 2) {
                    Text("Dynamic Rate")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(recommendation.recommendedRate, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(RevOwlTheme.gold)
                        .shadow(color: .black.opacity(0.15), radius: 0.5, y: 0.5)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(String(format: "%+.1f%%", recommendation.percentChange))
                        .font(.headline)
                        .foregroundStyle(recommendation.percentChange > 0 ? RevOwlTheme.positive : RevOwlTheme.negative)
                    Text("change")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "brain.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text("AI Reasoning")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                }
                Text(recommendation.reasoning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.purple.opacity(0.08), in: .rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.purple.opacity(0.15), lineWidth: 0.5)
            )

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption2)
                    Text("ADR \(recommendation.expectedADRImpact >= 0 ? "+" : "")\(recommendation.expectedADRImpact.formatted(.currency(code: "USD").precision(.fractionLength(0))))")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(RevOwlTheme.positive)

                HStack(spacing: 4) {
                    Image(systemName: "bed.double.fill")
                        .font(.caption2)
                    Text("Occ \(recommendation.expectedOccupancyImpact >= 0 ? "+" : "")\(Int(recommendation.expectedOccupancyImpact))%")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(recommendation.expectedOccupancyImpact >= 0 ? RevOwlTheme.positive : .orange)
            }

            if recommendation.status == .pending {
                HStack(spacing: 10) {
                    Button(action: onApply) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Apply Dynamic Rate")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(RevOwlTheme.goldGradient)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            LinearGradient(
                                                colors: [.white.opacity(0.2), .clear],
                                                startPoint: .top,
                                                endPoint: .center
                                            )
                                        )
                                )
                        }
                        .foregroundStyle(.white)
                        .shadow(color: RevOwlTheme.gold.opacity(0.3), radius: 8, y: 4)
                    }
                    .sensoryFeedback(.success, trigger: recommendation.status)

                    Button(action: onDismiss) {
                        HStack {
                            Image(systemName: "xmark")
                            Text("Dismiss")
                        }
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .glassCardStyle(cornerRadius: 12, elevation: .subtle)
                        .foregroundStyle(.secondary)
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: recommendation.status)
                }
            }
        }
        .padding(16)
        .glassCardStyle()
    }

    private var confidenceBadge: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 6, height: 6)
                .shadow(color: confidenceColor.opacity(0.5), radius: 3)
            Text(recommendation.confidence.rawValue)
                .font(.caption2.weight(.medium))
                .foregroundStyle(confidenceColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(confidenceColor.opacity(0.12), in: .capsule)
    }

    private var confidenceColor: Color {
        switch recommendation.confidence {
        case .high: return RevOwlTheme.positive
        case .medium: return .orange
        case .low: return RevOwlTheme.negative
        }
    }

    private var statusBadge: some View {
        Group {
            switch recommendation.status {
            case .applied:
                Label("Applied", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(RevOwlTheme.positive)
            case .dismissed:
                Label("Dismissed", systemImage: "xmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            case .snoozed:
                Label("Snoozed", systemImage: "clock.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            case .pending:
                EmptyView()
            }
        }
    }
}
