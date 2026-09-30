import RevenueCat
import SwiftUI

/// Plan cards for Essentials / Insight / Horizon. Prices come from the App Store when available.
struct PlanPicker: View {
    @Binding var selected: String
    var currentPlan: String?

    @Environment(AppModel.self) private var app
    @Environment(StoreViewModel.self) private var store

    var body: some View {
        VStack(spacing: 12) {
            if let plans = app.plans?.plans {
                ForEach(plans) { plan in
                    PlanCard(
                        plan: plan,
                        price: store.package(for: plan.id)?.storeProduct.localizedPriceString ?? plan.priceUsdMonthly.formatted(.currency(code: "USD").precision(.fractionLength(0))),
                        isSelected: selected == plan.id,
                        isCurrent: currentPlan == plan.id,
                        hasTrial: store.offersTrial(plan.id, serverTrialUsed: app.plan?.trialUsed ?? false)
                    ) {
                        selected = plan.id
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
        .task { if app.plans == nil { await app.loadPlans() } }
    }
}

private struct PlanCard: View {
    let plan: PublicPlan
    let price: String
    let isSelected: Bool
    let isCurrent: Bool
    let hasTrial: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(plan.name)
                        .font(.display(.title2, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    if plan.recommended {
                        Pill(text: "Recommended", icon: "star.fill", tint: Palette.gold, fill: Palette.goldSoft)
                    }
                    if isCurrent {
                        Pill(text: "Current", tint: Palette.sage, fill: Palette.sageSoft)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? Palette.teal : Palette.hairline)
                        .accessibilityHidden(true)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(price).font(.title3.weight(.bold)).foregroundStyle(Palette.ink)
                    Text("per hotel / month").font(.footnote).foregroundStyle(Palette.inkTertiary)
                }
                if hasTrial {
                    Label("7 days free, then \(price)/month", systemImage: "gift")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.teal)
                }
                Text(plan.tagline).font(.subheadline).foregroundStyle(Palette.inkSecondary)
                if isSelected {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(plan.features, id: \.self) { f in
                            Label(f, systemImage: "checkmark")
                                .font(.subheadline)
                                .foregroundStyle(Palette.ink)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Palette.surface : Palette.surfaceRaised, in: .rect(cornerRadius: Metrics.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cardRadius)
                    .strokeBorder(isSelected ? Palette.teal : Palette.hairline, lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(.smooth(duration: 0.25), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Select the \(plan.name) plan")
    }
}

/// Subscription terms shown under every purchase button (App Review requirement).
struct SubscriptionTerms: View {
    @Environment(StoreViewModel.self) private var store
    @Environment(AppModel.self) private var app
    @State private var restoredText: String?

    var body: some View {
        VStack(spacing: 10) {
            Text("Subscriptions are billed per hotel to your Apple Account and renew monthly unless cancelled at least 24 hours before the period ends. If you've had a free trial before, you'll be charged at purchase. Manage or cancel anytime in Settings.")
                .font(.caption)
                .foregroundStyle(Palette.inkTertiary)
                .multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Button(store.isRestoring ? "Restoring…" : "Restore purchases") {
                    Task {
                        if await store.restore() {
                            await app.syncBilling()
                            restoredText = "Purchases restored."
                        }
                    }
                }
                .disabled(store.isRestoring)
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Palette.teal)
            if let restoredText {
                Text(restoredText).font(.footnote).foregroundStyle(Palette.sage)
            }
        }
    }
}

/// Buys a plan, then waits for the backend to verify the entitlement with RevenueCat.
@MainActor
enum PlanPurchase {
    static func run(_ planId: String, app: AppModel, store: StoreViewModel) async -> Bool {
        guard await store.purchase(planId: planId) else { return false }
        for attempt in 0..<5 {
            await app.syncBilling()
            if app.plan?.isPaid == true { return true }
            try? await Task.sleep(for: .seconds(Double(attempt) + 1))
        }
        store.errorMessage = "Your purchase went through, but confirming it is taking longer than usual. Pull to refresh in a minute."
        return true
    }
}
