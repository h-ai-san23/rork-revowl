import SwiftUI

struct LocaleStep: View {
    @Environment(AppModel.self) private var app
    @State private var currency = "USD"
    @State private var timeZone = TimeZone.current.identifier
    @State private var showZones = false
    @State private var isWorking = false
    @State private var errorText: String?
    @State private var loaded = false

    var body: some View {
        StepScaffold(
            orev: isWorking ? .thinking : .explaining,
            title: "Currency and local time",
            message: "Reports and rates use this currency, and “today” follows your property's clock — not your phone's.",
            isWorking: isWorking,
            onPrimary: { Task { await save() } }
        ) {
            LocaleFields(currency: $currency, timeZone: $timeZone, showZones: $showZones)
            if let errorText { InlineMessage(kind: .error, text: errorText) }
        }
        .onAppear {
            guard !loaded, let p = app.profile else { return }
            loaded = true
            currency = p.currency
            timeZone = p.timeZone
        }
        .sheet(isPresented: $showZones) {
            TimeZonePickerSheet(selection: $timeZone)
        }
    }

    private func save() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }
        do {
            try await app.updateProfile(["currency": .string(currency), "timeZone": .string(timeZone)])
            app.goTo(.dataImport)
        } catch {
            errorText = error.userMessage
        }
    }
}

struct LocaleFields: View {
    @Binding var currency: String
    @Binding var timeZone: String
    @Binding var showZones: Bool

    private var currencies: [String] {
        CurrencyOptions.common.contains(currency) ? CurrencyOptions.common : [currency] + CurrencyOptions.common
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Currency").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.inkSecondary)
                Picker("Currency", selection: $currency) {
                    ForEach(currencies, id: \.self) { code in
                        Text("\(code) · \(CurrencyOptions.name(code))").tag(code)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fieldBackground()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Time zone").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.inkSecondary)
                Button { showZones = true } label: {
                    HStack {
                        Text(timeZone.replacingOccurrences(of: "_", with: " ")).foregroundStyle(Palette.ink)
                        Spacer()
                        Text(TimeZone(identifier: timeZone)?.abbreviation() ?? "").foregroundStyle(Palette.inkTertiary)
                        Image(systemName: "chevron.up.chevron.down").foregroundStyle(Palette.inkTertiary)
                    }
                    .fieldBackground()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Time zone, \(timeZone)")
            }
        }
        .card()
    }
}

struct TimeZonePickerSheet: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var zones: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers
        guard !search.trimmed.isEmpty else { return all }
        return all.filter { $0.replacingOccurrences(of: "_", with: " ").localizedStandardContains(search.trimmed) }
    }

    var body: some View {
        NavigationStack {
            List(zones, id: \.self) { zone in
                Button {
                    selection = zone
                    dismiss()
                } label: {
                    HStack {
                        Text(zone.replacingOccurrences(of: "_", with: " ")).foregroundStyle(Palette.ink)
                        Spacer()
                        if zone == selection { Image(systemName: "checkmark").foregroundStyle(Palette.teal) }
                    }
                }
            }
            .searchable(text: $search, prompt: "City or region")
            .navigationTitle("Time zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
