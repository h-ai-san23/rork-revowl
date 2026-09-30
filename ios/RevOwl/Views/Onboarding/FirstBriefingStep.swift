import SwiftUI

struct FirstBriefingStep: View {
    @Environment(AppModel.self) private var app
    @State private var briefing: Briefing?
    @State private var errorText: String?
    @State private var isFinishing = false

    var body: some View {
        StepScaffold(
            orev: briefing.map { OrevState(mood: $0.mood) } ?? (errorText == nil ? .thinking : .errorRecovery),
            title: briefing == nil ? "Preparing your first briefing…" : "Your first briefing",
            message: briefing?.summary ?? (errorText ?? "I'm reading your numbers and your market."),
            primaryTitle: "Open my dashboard",
            primaryEnabled: briefing != nil || errorText != nil,
            isWorking: isFinishing,
            onPrimary: {
                Task {
                    isFinishing = true
                    await app.completeSetup()
                    isFinishing = false
                }
            }
        ) {
            if let b = briefing {
                if b.hasSampleData { SampleDataBanner() }
                if !b.headline.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(b.headline) { MetricTile(metric: $0) }
                    }
                }
                ForEach(b.insights.prefix(3)) { InsightCard(insight: $0) }
                if !b.dataGaps.isEmpty { DataGapsCard(gaps: b.dataGaps) }
            } else if errorText != nil {
                Button("Try again") { Task { await load() } }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .task { await load() }
    }

    private func load() async {
        errorText = nil
        do {
            briefing = try await app.api.get(app.path("/briefing"), query: ["refresh": "1"])
        } catch {
            errorText = "\(error.userMessage) You can open the dashboard and I'll try again there."
        }
    }
}
