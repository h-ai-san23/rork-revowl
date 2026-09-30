import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var app
    @State private var briefing: Briefing?
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var showImport = false

    private var orevState: OrevState {
        if isLoading && briefing == nil { return .thinking }
        if errorText != nil && briefing == nil { return .errorRecovery }
        return briefing.map { OrevState(mood: $0.mood) } ?? .idle
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                PlanStatusBanner()
                if let b = briefing {
                    if b.hasSampleData { SampleDataBanner() }
                    if !b.headline.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                            ForEach(b.headline) { MetricTile(metric: $0) }
                        }
                    }
                    if !b.insights.isEmpty {
                        SectionHeader(title: "Worth your attention", subtitle: "Every number links to its source.")
                        ForEach(b.insights) { insight in
                            InsightCard(insight: insight) { handle($0, insight: insight) }
                        }
                    }
                    if !b.dataGaps.isEmpty { DataGapsCard(gaps: b.dataGaps) }
                    quickAsk
                    Text("Briefing prepared \(Fmt.relative(ms: b.generatedAt)) · \(b.summarySource == "orev" ? "Written by Orev from calculated figures" : "Calculated figures")")
                        .font(.caption)
                        .foregroundStyle(Palette.inkTertiary)
                        .frame(maxWidth: .infinity)
                } else if let errorText {
                    InlineMessage(kind: .error, text: errorText, actionTitle: "Try again") {
                        Task { await load(force: false) }
                    }
                } else {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: Metrics.cardRadius)
                            .fill(Palette.surface)
                            .frame(height: 110)
                            .redacted(reason: .placeholder)
                    }
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 24)
        }
        .background(AppBackground())
        .navigationTitle("Today")
        .navigationSubtitle(app.profile?.name ?? "")
        .refreshable { await load(force: true) }
        .task(id: app.dataVersion) { await load(force: false) }
        .sheet(isPresented: $showImport) {
            NavigationStack {
                ScrollView { DataImportPanel(showSampleOption: false).padding(Metrics.margin) }
                    .background(AppBackground())
                    .navigationTitle("Add your data")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showImport = false } } }
            }
        }
    }

    private var header: some View {
        OrevBubble(
            state: orevState,
            title: briefing?.greeting ?? "Good day",
            message: briefing?.summary ?? (isLoading ? "Checking your numbers and market…" : nil),
            size: 88
        )
        .padding(.top, 4)
    }

    private var quickAsk: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask Orev").font(.headline).foregroundStyle(Palette.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["How did last week go?", "Which dates look soft?", "How do I compare to competitors?", "What events are coming up?"], id: \.self) { q in
                        Button(q) { app.ask(q) }.buttonStyle(ChipButtonStyle())
                    }
                }
            }
            .scrollClipDisabled()
        }
        .card()
    }

    private func handle(_ action: InsightAction, insight: Insight) {
        switch action.target {
        case "import": showImport = true
        case "market": app.selectedTab = .market
        case "calendar": app.selectedTab = .calendar
        case "competitors", "property": app.selectedTab = .property
        case "ask": app.ask("Explain this: \(insight.title). What's driving it?")
        default: break
        }
    }

    private func load(force: Bool) async {
        guard app.propertyId != nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result: Briefing = try await app.api.get(app.path("/briefing"), query: force ? ["refresh": "1"] : [:])
            withAnimation(.smooth) { briefing = result }
            errorText = nil
            if force { await app.refreshOverview() }
        } catch is CancellationError {
        } catch {
            errorText = error.userMessage
        }
    }
}
