import SwiftUI

struct DataManagerView: View {
    @Environment(AppModel.self) private var app
    @State private var rows: [PerformanceRow] = []
    @State private var errorText: String?
    @State private var showRemoveSample = false

    private var hasSample: Bool { (app.overview?.counts.sampleDays ?? 0) > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if hasSample {
                    VStack(alignment: .leading, spacing: 10) {
                        SampleDataBanner()
                        Button("Remove sample data", role: .destructive) { showRemoveSample = true }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
                if app.canEdit {
                    DataImportPanel(showSampleOption: !hasSample && (app.overview?.counts.performanceDays ?? 0) == 0) {
                        Task { await load() }
                    }
                }
                SectionHeader(title: "Recent days", subtitle: "Last 30 days and next 30 days")
                if rows.isEmpty {
                    Text("No data yet.").font(.subheadline).foregroundStyle(Palette.inkSecondary).card()
                } else {
                    VStack(spacing: 0) {
                        ForEach(rows.reversed(), id: \.self) { r in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Fmt.day(r.date)).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                                    BasisBadge(basis: r.source == "sample" ? "sample" : r.kind)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(r.roomsSold)/\(r.roomsAvailable) · \(Fmt.percent(r.occupancy))").font(.subheadline).foregroundStyle(Palette.ink)
                                    Text(r.roomRevenue.map { Fmt.money($0, app.currency) } ?? "No revenue").font(.caption).foregroundStyle(Palette.inkTertiary)
                                }
                            }
                            .padding(.vertical, 8)
                            .accessibilityElement(children: .combine)
                            Divider().overlay(Palette.hairline)
                        }
                    }
                    .card(padding: 12)
                }
                if let errorText { InlineMessage(kind: .error, text: errorText) }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 24)
        }
        .background(AppBackground())
        .navigationTitle("Performance data")
        .task(id: app.dataVersion) { await load() }
        .confirmationDialog("Remove all sample data?", isPresented: $showRemoveSample, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { Task { await removeSample() } }
        } message: {
            Text("Your own imported days are not affected.")
        }
    }

    private func load() async {
        do {
            let res: PerformanceResponse = try await app.api.get(app.path("/performance"))
            rows = res.rows
        } catch is CancellationError {
        } catch {
            errorText = error.userMessage
        }
    }

    private func removeSample() async {
        do {
            let _: OKResponse = try await app.api.delete(app.path("/sample-data"))
            app.dataChanged()
        } catch {
            errorText = error.userMessage
        }
    }
}
