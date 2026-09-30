import SwiftUI

struct PaywallSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(StoreViewModel.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selected = "insight"
    @State private var isWorking = false

    private var current: String? { app.plan?.isPaid == true ? app.plan?.id : nil }
    private var hasTrial: Bool { store.offersTrial(selected, serverTrialUsed: app.plan?.trialUsed ?? false) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    OrevBubble(
                        state: .opportunity,
                        title: current == nil ? "Unlock your full briefing" : "Change your plan",
                        message: current == nil
                            ? "Your data and direct views stay available. A plan adds scheduled market refreshes, more competitors and more Orev answers."
                            : "Switching takes effect through the App Store. A plan change doesn't restart a free trial."
                    )
                    PlanPicker(selected: $selected, currentPlan: current)
                    if let error = store.errorMessage { InlineMessage(kind: .error, text: error) }
                    SubscriptionTerms()
                }
                .padding(Metrics.margin)
            }
            .background(AppBackground())
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await buy() }
                } label: {
                    if isWorking { ProgressView().tint(Palette.onAccent) } else { Text(buttonTitle) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selected == current || store.package(for: selected) == nil || isWorking)
                .padding(.horizontal, Metrics.margin)
                .padding(.vertical, 8)
            }
            .navigationTitle("Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .onAppear {
                store.errorMessage = nil
                if let current { selected = current == "horizon" ? "horizon" : (current == "insight" ? "horizon" : "insight") }
            }
        }
    }

    private var buttonTitle: String {
        if selected == current { return "Your current plan" }
        if hasTrial { return "Start 7-day free trial" }
        return current == nil ? "Subscribe to \(app.planName(selected))" : "Switch to \(app.planName(selected))"
    }

    private func buy() async {
        isWorking = true
        defer { isWorking = false }
        if await PlanPurchase.run(selected, app: app, store: store) { dismiss() }
    }
}
