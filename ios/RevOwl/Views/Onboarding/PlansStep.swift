import SwiftUI

struct PlansStep: View {
    @Environment(AppModel.self) private var app
    @Environment(StoreViewModel.self) private var store
    @State private var selected = "insight"
    @State private var isWorking = false

    private var hasTrial: Bool { store.offersTrial(selected, serverTrialUsed: app.plan?.trialUsed ?? false) }

    var body: some View {
        StepScaffold(
            orev: isWorking ? .thinking : (store.errorMessage != nil ? .errorRecovery : .opportunity),
            title: "Choose how much I watch",
            message: "Plans are per hotel. Insight is what I'd recommend for most independent properties — you can switch anytime.",
            primaryTitle: app.plan?.isPaid == true ? "Continue" : (hasTrial ? "Start 7-day free trial" : "Subscribe to \(app.planName(selected))"),
            primaryEnabled: store.package(for: selected) != nil || app.plan?.isPaid == true,
            isWorking: isWorking || store.purchasingPlanId != nil,
            secondaryTitle: app.plan?.isPaid == true ? nil : "Not now",
            onPrimary: { Task { await buy() } },
            onSecondary: { app.goTo(.briefing) }
        ) {
            if app.plan?.isPaid == true, let plan = app.plan {
                InlineMessage(kind: .success, text: "\(app.planName(plan.id)) is active\(plan.state == "trial" ? " (free trial)" : "").")
            }
            PlanPicker(selected: $selected, currentPlan: app.plan?.isPaid == true ? app.plan?.id : nil)
            if store.offering == nil && !store.isLoading {
                InlineMessage(kind: .warning, text: "Plans couldn't be loaded from the App Store.", actionTitle: "Try again") {
                    Task { await store.loadOfferings() }
                }
            }
            if let error = store.errorMessage {
                InlineMessage(kind: .error, text: error)
            }
            SubscriptionTerms()
        }
        .onAppear { store.errorMessage = nil }
    }

    private func buy() async {
        if app.plan?.isPaid == true {
            app.goTo(.briefing)
            return
        }
        isWorking = true
        defer { isWorking = false }
        if await PlanPurchase.run(selected, app: app, store: store) {
            app.goTo(.briefing)
        }
    }
}
