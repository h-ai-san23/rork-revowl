import SwiftUI

struct SubscriptionView: View {
    @Environment(AppState.self) private var appState
    @Environment(StoreViewModel.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTier: SubscriptionTier = .pro

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(RevOwlTheme.gold)
                        .shadow(color: RevOwlTheme.gold.opacity(0.4), radius: 12)
                    Text("RevOwl Pro")
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                    Text("Smarter Rates. Fuller Rooms.\nZero Guesswork.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                VStack(spacing: 12) {
                    ForEach(SubscriptionTier.allCases) { tier in
                        tierCard(tier)
                    }
                }

                featureComparisonTable

                VStack(spacing: 12) {
                    Button {
                        handleSubscribe()
                    } label: {
                        if store.isPurchasing {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text(ctaTitle)
                        }
                    }
                    .buttonStyle(GoldButtonStyle())
                    .disabled(store.isPurchasing || (selectedTier == store.entitledTier && selectedTier != .scout))
                    .sensoryFeedback(.impact(weight: .medium), trigger: selectedTier)

                    Button("Restore Purchases") {
                        Task { await store.restore() }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .disabled(store.isRestoring)

                    Text("Billed monthly. Cancel anytime in Settings.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(20)
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .deepGlassBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(RevOwlTheme.gold)
            }
        }
        .task {
            if store.offerings == nil {
                await store.fetchOfferings()
            }
        }
        .alert("Error", isPresented: errorBinding) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }

    private var ctaTitle: String {
        if selectedTier == .scout { return "Continue with Free Plan" }
        if selectedTier == store.entitledTier { return "Current Plan" }
        return "Subscribe — \(store.priceText(for: selectedTier))"
    }

    private func handleSubscribe() {
        if selectedTier == .scout {
            dismiss()
            return
        }
        Task {
            let success = await store.purchase(tier: selectedTier)
            if success { dismiss() }
        }
    }

    private func tierCard(_ tier: SubscriptionTier) -> some View {
        let isSelected = selectedTier == tier
        let isCurrent = appState.currentTier == tier

        return Button {
            selectedTier = tier
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(tier.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if isCurrent {
                            Text("Current")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(RevOwlTheme.gold.opacity(0.2), in: .capsule)
                                .foregroundStyle(RevOwlTheme.gold)
                        }
                    }
                    Text(tierSubtitle(tier))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(store.priceText(for: tier))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isSelected ? RevOwlTheme.gold : .primary)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? RevOwlTheme.gold : Color.gray.opacity(0.4))
                    .font(.title3)
            }
            .padding(16)
            .glassCardStyle(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? RevOwlTheme.gold.opacity(0.4) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(GlassPressButtonStyle())
        .sensoryFeedback(.selection, trigger: selectedTier)
    }

    private func tierSubtitle(_ tier: SubscriptionTier) -> String {
        switch tier {
        case .scout: return "Track 1 competitor, basic demand"
        case .growth: return "3 competitors, events + airport"
        case .pro: return "Full dynamic pricing, all signals"
        }
    }

    private var featureComparisonTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Feature Comparison")
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.bottom, 12)

            featureRow("Competitors", "1", "3", "5")
            featureRow("Rate Refresh", "6hr", "2hr", "2x/hr")
            featureRow("History", "7 days", "30 days", "90 days")
            featureRow("Dynamic Pricing", "—", "Limited", "Full")
            featureRow("Demand Signals", "Basic", "Events+", "All")
            featureRow("Revenue Analytics", "—", "Basic", "Advanced")
            featureRow("PDF Reports", "—", "—", "✓")
        }
        .padding(16)
        .glassCardStyle(cornerRadius: 16)
    }

    private func featureRow(_ feature: String, _ scout: String, _ growth: String, _ pro: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(feature)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 100, alignment: .leading)
                Spacer()
                Text(scout)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 50)
                Text(growth)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 50)
                Text(pro)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(RevOwlTheme.gold)
                    .frame(width: 50)
            }
            .padding(.vertical, 8)
            Rectangle()
                .fill(Color.primary.opacity(0.04))
                .frame(height: 0.5)
        }
    }
}
