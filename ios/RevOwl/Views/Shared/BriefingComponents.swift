import SwiftUI

struct MetricTile: View {
    let metric: HeadlineMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(metric.label.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Palette.inkTertiary)
            Text(metric.formatted)
                .font(.display(.title, weight: .bold))
                .foregroundStyle(metric.value == nil ? Palette.inkTertiary : Palette.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .contentTransition(.numericText())
            BasisBadge(basis: metric.basis)
            Text(metric.note ?? metric.period)
                .font(.caption)
                .foregroundStyle(Palette.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

struct InsightCard: View {
    let insight: Insight
    var onAction: ((InsightAction) -> Void)?
    @State private var showEvidence = false

    private var tint: Color {
        switch insight.kind {
        case "opportunity": Palette.gold
        case "risk": Palette.coral
        case "action": Palette.teal
        default: Palette.sage
        }
    }

    private var icon: String {
        switch insight.kind {
        case "opportunity": "sparkles"
        case "risk": "exclamationmark.triangle"
        case "action": "arrow.right.circle"
        default: insight.labels.contains("Unverified") || insight.labels.contains("Confirmed") ? "ticket" : "chart.line.uptrend.xyaxis"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.14), in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title).font(.headline).foregroundStyle(Palette.ink)
                    Text(insight.detail).font(.subheadline).foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !insight.labels.isEmpty {
                HStack(spacing: 6) {
                    ForEach(insight.labels, id: \.self) { label in
                        Pill(text: label, tint: Palette.inkSecondary, fill: Palette.surfaceRaised)
                    }
                }
            }
            HStack {
                if !insight.evidence.isEmpty {
                    Button(showEvidence ? "Hide evidence" : "Show evidence") {
                        withAnimation(.smooth) { showEvidence.toggle() }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.teal)
                    .frame(minHeight: 44)
                }
                Spacer()
                if let action = insight.action, let onAction {
                    Button(action.label) { onAction(action) }
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.glass)
                }
            }
            if showEvidence {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(insight.evidence.enumerated()), id: \.offset) { _, e in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.label).font(.caption.weight(.semibold)).foregroundStyle(Palette.ink)
                                Text([e.source, e.asOf.map { "as of \(Fmt.day($0))" }].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption2).foregroundStyle(Palette.inkTertiary)
                            }
                            Spacer()
                            Text(e.value).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(12)
                .background(Palette.surfaceRaised, in: .rect(cornerRadius: Metrics.smallRadius))
                .transition(.opacity)
            }
        }
        .card()
    }
}

struct DataGapsCard: View {
    let gaps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("What I can't see yet", systemImage: "eye.slash")
                .font(.headline)
                .foregroundStyle(Palette.ink)
            ForEach(gaps, id: \.self) { gap in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(Palette.gold).frame(width: 6, height: 6).padding(.top, 7)
                    Text(gap).font(.subheadline).foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .card(fill: Palette.surfaceRaised)
    }
}

struct SampleDataBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "flask.fill").foregroundStyle(Palette.coral)
            Text("You're looking at sample data. Import your own numbers for real insights.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.ink)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.coralSoft, in: .rect(cornerRadius: Metrics.smallRadius))
        .accessibilityElement(children: .combine)
    }
}
