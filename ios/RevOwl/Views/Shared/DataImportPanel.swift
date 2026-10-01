import SwiftUI
import UniformTypeIdentifiers

/// CSV upload with a validated preview, manual daily entry, and clearly-labelled sample data.
struct DataImportPanel: View {
    var showSampleOption: Bool = true
    var onChange: () -> Void = {}

    @Environment(AppModel.self) private var app
    @State private var showFile = false
    @State private var csvText: String?
    @State private var fileName: String?
    @State private var preview: CsvPreview?
    @State private var isWorking = false
    @State private var errorText: String?
    @State private var successText: String?
    @State private var showManual = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Upload a report", systemImage: "doc.text")
                    .font(.headline).foregroundStyle(Palette.ink)
                Text("Export a daily report from your PMS as CSV. I need a date and rooms sold; room revenue and rooms available are recommended. Past dates count as actuals, future dates as on the books.")
                    .font(.subheadline).foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let preview {
                    PreviewSummary(preview: preview, fileName: fileName)
                    HStack(spacing: 10) {
                        Button("Cancel") { reset() }
                            .buttonStyle(SecondaryButtonStyle())
                        Button {
                            Task { await commit() }
                        } label: {
                            if isWorking { ProgressView().tint(Palette.onAccent) } else { Text("Import \(preview.validRows) days") }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(preview.validRows == 0 || isWorking)
                    }
                } else {
                    Button {
                        showFile = true
                    } label: {
                        if isWorking { ProgressView() } else { Label("Choose CSV file", systemImage: "square.and.arrow.down") }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(isWorking)
                    .accessibilityIdentifier("data.chooseCSV")
                }
            }
            .card()

            VStack(alignment: .leading, spacing: 10) {
                Label("Enter numbers by hand", systemImage: "square.and.pencil")
                    .font(.headline).foregroundStyle(Palette.ink)
                Text("Add yesterday's results, or on-the-books numbers for a future date.")
                    .font(.subheadline).foregroundStyle(Palette.inkSecondary)
                Button("Add a day") { showManual = true }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityIdentifier("data.addDay")
            }
            .card()

            if showSampleOption {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Explore with sample data", systemImage: "flask")
                            .font(.headline).foregroundStyle(Palette.ink)
                        Spacer()
                        BasisBadge(basis: "sample")
                    }
                    Text("Fill the app with demonstration numbers so you can see how it works. Sample data is always labelled and never mixed with your real days. Remove it anytime in Property → Data.")
                        .font(.subheadline).foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Load sample data") { Task { await loadSample() } }
                        .buttonStyle(SecondaryButtonStyle())
                        .accessibilityIdentifier("data.loadSample")
                        .disabled(isWorking)
                }
                .card(fill: Palette.surfaceRaised)
            }

            if let errorText { InlineMessage(kind: .error, text: errorText) }
            if let successText { InlineMessage(kind: .success, text: successText) }
        }
        .fileImporter(isPresented: $showFile, allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .text]) { result in
            handleFile(result)
        }
        .sheet(isPresented: $showManual) {
            ManualEntrySheet {
                successText = "Saved. Your metrics are updated."
                onChange()
            }
        }
    }

    private func reset() {
        preview = nil
        csvText = nil
        fileName = nil
    }

    private func handleFile(_ result: Result<URL, Error>) {
        errorText = nil
        successText = nil
        guard case .success(let url) = result else {
            errorText = "That file couldn't be opened."
            return
        }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            errorText = "That file couldn't be read."
            return
        }
        guard data.count <= 1_800_000 else {
            errorText = "That file is too large. Export up to about a year of daily rows."
            return
        }
        let text = String(decoding: data, as: UTF8.self)
        csvText = text
        fileName = url.lastPathComponent
        Task { await requestPreview(text) }
    }

    private func requestPreview(_ text: String) async {
        isWorking = true
        defer { isWorking = false }
        do {
            preview = try await app.api.post(app.path("/performance/import-csv"), json: ["csv": .string(text), "commit": false])
        } catch {
            errorText = error.userMessage
            reset()
        }
    }

    private func commit() async {
        guard let csvText else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let result: CsvPreview = try await app.api.post(
                app.path("/performance/import-csv"),
                json: ["csv": .string(csvText), "commit": true, "fileName": .from(fileName)]
            )
            successText = "Imported \(result.validRows) days. Metrics are calculated from these numbers only."
            reset()
            app.dataChanged()
            onChange()
        } catch {
            errorText = error.userMessage
        }
    }

    private func loadSample() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }
        do {
            let _: OKResponse = try await app.api.post(app.path("/sample-data"))
            successText = "Sample data loaded. Look for the “Sample data” label."
            app.dataChanged()
            onChange()
        } catch {
            errorText = error.userMessage
        }
    }
}

private struct PreviewSummary: View {
    let preview: CsvPreview
    let fileName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let fileName {
                Text(fileName).font(.footnote.weight(.semibold)).foregroundStyle(Palette.inkTertiary)
            }
            HStack(spacing: 16) {
                stat("\(preview.validRows)", "valid days")
                stat("\(preview.actualDays)", "actual")
                stat("\(preview.onTheBooksDays)", "on the books")
            }
            if let range = preview.range {
                Text("\(Fmt.day(range.start)) → \(Fmt.day(range.end))")
                    .font(.subheadline).foregroundStyle(Palette.inkSecondary)
            }
            if preview.issueCount > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(preview.issueCount) row\(preview.issueCount == 1 ? "" : "s") will be skipped:")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.coral)
                    ForEach(Array(preview.issues.prefix(5).enumerated()), id: \.offset) { _, issue in
                        Text("Row \(issue.row): \(issue.message)")
                            .font(.caption).foregroundStyle(Palette.inkSecondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surfaceRaised, in: .rect(cornerRadius: Metrics.smallRadius))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.title3.weight(.bold)).foregroundStyle(Palette.ink)
            Text(label).font(.caption).foregroundStyle(Palette.inkTertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Adds or corrects one day of performance.
struct ManualEntrySheet: View {
    var onSaved: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now
    @State private var roomsSold = ""
    @State private var revenue = ""
    @State private var available = ""
    @State private var isWorking = false
    @State private var errorText: String?

    private var iso: String { Fmt.localISO(date) }
    private var isFuture: Bool { iso >= app.today }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    LabeledContent("Counts as") {
                        BasisBadge(basis: isFuture ? "on_the_books" : "actual")
                    }
                }
                Section {
                    LabeledContent("Rooms sold") {
                        TextField("Required", text: $roomsSold)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("manual.roomsSold")
                    }
                    LabeledContent("Room revenue (\(app.currency))") {
                        TextField("Optional", text: $revenue)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("manual.revenue")
                    }
                    LabeledContent("Rooms available") {
                        TextField("Room count", text: $available)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("manual.available")
                    }
                } footer: {
                    Text("Room revenue is optional, but without it ADR and RevPAR can't be calculated. Rooms available defaults to your room count.")
                }
                if let errorText {
                    Section { Text(errorText).foregroundStyle(Palette.coral) }
                }
            }
            .navigationTitle("Add a day")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(Int(roomsSold.trimmed) == nil || isWorking)
                        .accessibilityIdentifier("manual.save")
                }
            }
            .onAppear {
                if let d = Fmt.localDate(Fmt.addDays(app.today, -1)) { date = d }
                if let r = app.profile?.roomCount { available = String(r) }
            }
        }
    }

    private func save() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }
        var row: [String: JSONValue] = [
            "date": .string(iso),
            "roomsSold": .from(Int(roomsSold.trimmed)),
            "roomRevenue": .from(revenue.trimmed.isEmpty ? nil : Fmt.parseNumber(revenue)),
        ]
        if let a = Int(available.trimmed) { row["roomsAvailable"] = .number(Double(a)) }
        do {
            let result: WriteResult = try await app.api.post(app.path("/performance"), json: ["rows": .array([.object(row)])])
            if let issue = result.issues.first {
                errorText = issue.message
                return
            }
            app.dataChanged()
            onSaved()
            dismiss()
        } catch {
            errorText = error.userMessage
        }
    }
}
