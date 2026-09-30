import SwiftUI

struct PlanManageView: View {
    @Environment(AppModel.self) private var app
    @Environment(StoreViewModel.self) private var store
    @State private var usage: UsageInfo?
    @State private var isSyncing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let plan = app.plan {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(app.planName(plan.isPaid ? plan.id : plan.purchasedPlan)).font(.display(.title2, weight: .bold)).foregroundStyle(Palette.ink)
                            Spacer()
                            Pill(text: stateLabel(plan.state), tint: plan.isPaid ? Palette.sage : Palette.gold, fill: plan.isPaid ? Palette.sageSoft : Palette.goldSoft)
                        }
                        if let exp = plan.expiresAt {
                            Text(plan.willRenew ? "Renews \(Fmt.shortDate(ms: exp))" : "Access until \(Fmt.shortDate(ms: exp))")
                                .font(.subheadline).foregroundStyle(Palette.inkSecondary)
                        }
                        Divider().overlay(Palette.hairline)
                        limitRow("Competitors tracked", "\(app.overview?.counts.activeCompetitors ?? 0) of \(plan.limits.competitors)")
                        limitRow("Team seats", "\(app.overview?.counts.members ?? 0) of \(plan.limits.teamMembers)")
                        limitRow("Rate refreshes", "\(plan.limits.rateRefreshesPerDay)× daily, \(plan.limits.rateHorizonDays) days ahead")
                        limitRow("Event calendar", "\(plan.limits.eventHorizonDays) days")
                        if let usage {
                            VStack(alignment: .leading, spacing: 6) {
                                limitRow("Orev answers", "\(usage.orevAnswersUsed) of \(usage.orevAnswersAllowed) this \(plan.state == "trial" ? "trial" : "month")")
                                ProgressView(value: Double(min(usage.orevAnswersUsed, usage.orevAnswersAllowed)), total: Double(max(1, usage.orevAnswersAllowed)))
                                    .tint(Palette.teal)
                            }
                            if usage.budgetReached {
                                InlineMessage(kind: .warning, text: "AI features are paused until next month to keep costs within your plan. Your data and views still work, and you won't be charged extra.")
                            }
                        }
                    }
                    .card()
                }
                Button(app.plan?.isPaid == true ? "Change plan" : "Choose a plan") { app.showPaywall = true }
                    .buttonStyle(PrimaryButtonStyle())
                if let url = app.plan?.managementUrl.flatMap(URL.init(string:)) {
                    Link("Manage subscription in the App Store", destination: url)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                Button(isSyncing ? "Checking…" : "Refresh subscription status") {
                    Task {
                        isSyncing = true
                        await app.syncBilling()
                        await loadUsage()
                        isSyncing = false
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isSyncing)
                Text("Downgrading keeps your data. If you have more competitors or teammates than the new plan allows, choose which to keep in Competitors and Team.")
                    .font(.footnote).foregroundStyle(Palette.inkTertiary)
                SubscriptionTerms()
            }
            .padding(Metrics.margin)
        }
        .background(AppBackground())
        .navigationTitle("Plan")
        .task { await loadUsage() }
    }

    private func loadUsage() async {
        usage = try? await app.api.get(app.path("/usage"))
    }

    private func stateLabel(_ s: String) -> String {
        switch s {
        case "trial": "Free trial"
        case "active": "Active"
        case "grace": "Payment issue"
        case "expired": "Ended"
        default: "No plan"
        }
    }

    private func limitRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(Palette.inkSecondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .combine)
    }
}
