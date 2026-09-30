import SwiftUI

struct ImportStep: View {
    @Environment(AppModel.self) private var app

    private var hasData: Bool {
        (app.overview?.counts.performanceDays ?? 0) + (app.overview?.counts.sampleDays ?? 0) > 0
    }

    var body: some View {
        StepScaffold(
            orev: hasData ? .celebrating : .explaining,
            title: hasData ? "Got your numbers" : "Share your recent performance",
            message: hasData
                ? "I'll calculate occupancy, ADR and RevPAR from these days. You can add more anytime."
                : "Occupancy, ADR and RevPAR only come from your data, so I can't brief you properly without it. The last 30–60 days is a great start.",
            primaryTitle: hasData ? "Continue" : "Skip for now",
            onPrimary: { app.goTo(.competitors) }
        ) {
            DataImportPanel()
        }
    }
}
