import SwiftUI

struct OverviewStep: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        StepScaffold(
            orev: .explaining,
            title: "Here's your setup",
            message: "Tap any line to change it. Next, choose a plan — every plan starts with a free week if you haven't had a trial before.",
            primaryTitle: "See plans",
            onPrimary: { app.goTo(.plans) }
        ) {
            if let o = app.overview {
                let p = o.profile
                VStack(spacing: 0) {
                    row("building.2", "Property", [p.name, p.city].compactMap { $0 }.joined(separator: " · "), done: true, step: .confirm)
                    row("bed.double", "Rooms", p.roomCount.map { "\($0) rooms" } ?? "Not set", done: p.roomCount != nil, step: .rooms)
                    row("globe", "Currency & time", "\(p.currency) · \(p.timeZone.replacingOccurrences(of: "_", with: " "))", done: true, step: .locale)
                    row("chart.bar", "Your data", dataText(o.counts), done: o.counts.performanceDays + o.counts.sampleDays > 0, step: .dataImport)
                    row("link", "Public listing", p.xoteloName ?? "Not matched", done: p.xoteloKey != nil, step: .competitors)
                    row("binoculars", "Competitors", o.counts.competitors == 0 ? "None yet" : "\(o.counts.competitors) saved", done: o.counts.competitors > 0, step: .competitors)
                    row("target", "Goals", p.goals.isEmpty ? "None" : "\(p.goals.count) selected", done: !p.goals.isEmpty, step: .goals, last: true)
                }
                .card(padding: 6)

                VStack(alignment: .leading, spacing: 8) {
                    Text("What Orev will do").font(.headline).foregroundStyle(Palette.ink)
                    bullet("Brief you every morning from your own numbers.")
                    bullet("Watch competitors' lowest public rates (Beta, partial coverage).")
                    bullet("Flag local events — always with a source, marked unverified until you confirm.")
                    bullet("Answer questions, and say plainly when data is missing.")
                }
                .card()
            }
        }
    }

    private func dataText(_ c: PropertyCounts) -> String {
        if c.performanceDays > 0 { return "\(c.performanceDays) days imported" }
        if c.sampleDays > 0 { return "Sample data only" }
        return "Not added yet"
    }

    private func bullet(_ text: String) -> some View {
        Label(text, systemImage: "checkmark")
            .font(.subheadline)
            .foregroundStyle(Palette.inkSecondary)
    }

    private func row(_ icon: String, _ title: String, _ value: String, done: Bool, step: OnboardingStep, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            Button { app.goTo(step) } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundStyle(Palette.teal)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                        Text(value).font(.footnote).foregroundStyle(Palette.inkSecondary).lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: done ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundStyle(done ? Palette.sage : Palette.gold)
                        .accessibilityLabel(done ? "Done" : "Needs attention")
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Palette.inkTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit \(title)")
            if !last { Divider().overlay(Palette.hairline).padding(.leading, 52) }
        }
    }
}
