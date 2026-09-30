import SwiftUI

/// Shows trial/expiry/billing issues and a way to pick a plan. Never blocks direct controls.
struct PlanStatusBanner: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        if let plan = app.plan {
            if !plan.isPaid {
                banner(
                    icon: "sparkles",
                    title: plan.state == "expired" ? "Your plan has ended" : "No plan yet",
                    text: plan.state == "expired"
                        ? "Your data is safe. Scheduled refreshes and most Orev answers are paused."
                        : "Start a free week of \(app.planName("insight")) for scheduled market refreshes and more Orev answers.",
                    tint: Palette.gold, fill: Palette.goldSoft, cta: "See plans"
                )
            } else if plan.billingIssue {
                banner(icon: "creditcard.trianglebadge.exclamationmark", title: "Payment issue",
                       text: "Apple couldn't renew your subscription. Update your payment method to keep your plan.",
                       tint: Palette.coral, fill: Palette.coralSoft, cta: nil, link: plan.managementUrl)
            } else if plan.state == "trial", let exp = plan.expiresAt {
                banner(icon: "gift", title: "\(app.planName(plan.id)) trial",
                       text: "Free until \(Fmt.shortDate(ms: exp)). \(plan.willRenew ? "Your plan starts automatically after that." : "It won't renew.")",
                       tint: Palette.teal, fill: Palette.tealSoft, cta: nil)
            }
        }
    }

    private func banner(icon: String, title: String, text: String, tint: Color, fill: Color, cta: String?, link: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.headline).foregroundStyle(tint).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                Text(text).font(.footnote).foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let cta {
                    Button(cta) { app.showPaywall = true }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(minHeight: 36)
                }
                if let link, let url = URL(string: link) {
                    Link("Manage subscription", destination: url)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(minHeight: 36)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(fill, in: .rect(cornerRadius: Metrics.smallRadius))
    }
}
