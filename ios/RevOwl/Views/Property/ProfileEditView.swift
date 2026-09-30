import SwiftUI

struct ProfileEditView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var city = ""
    @State private var country = ""
    @State private var phone = ""
    @State private var website = ""
    @State private var rooms = ""
    @State private var propertyType = ""
    @State private var goals: [String] = []
    @State private var isWorking = false
    @State private var errorText: String?
    @State private var loaded = false

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Property name", text: $name)
                TextField("Address", text: $address, axis: .vertical)
                TextField("City", text: $city)
                TextField("Country", text: $country)
                TextField("Phone", text: $phone).keyboardType(.phonePad)
                TextField("Website", text: $website).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Property type", text: $propertyType)
            }
            Section {
                TextField("Sellable rooms", text: $rooms).keyboardType(.numberPad)
            } header: {
                Text("Inventory")
            } footer: {
                Text("Used as rooms available when a report doesn't include it.")
            }
            Section("Goals") {
                ForEach(GoalOption.all) { g in
                    Toggle(g.title, isOn: Binding(
                        get: { goals.contains(g.id) },
                        set: { on in
                            if on, goals.count < 4 { goals.append(g.id) } else if !on { goals.removeAll { $0 == g.id } }
                        }
                    ))
                    .tint(Palette.teal)
                    .disabled(!app.canEdit)
                }
            }
            if let sources = app.profile?.fieldSources.filter({ $0.value.source == "website" }), !sources.isEmpty {
                Section("From your website") {
                    ForEach(sources.keys.sorted(), id: \.self) { key in
                        LabeledContent(key.capitalized, value: "\(sources[key]?.confidence?.capitalized ?? "—") confidence")
                    }
                }
            }
            if let errorText { Section { Text(errorText).foregroundStyle(Palette.coral) } }
        }
        .disabled(!app.canEdit)
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Details")
        .toolbar {
            if app.canEdit {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(name.trimmed.isEmpty || isWorking)
                }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded, let p = app.profile else { return }
        loaded = true
        name = p.name
        address = p.address ?? ""
        city = p.city ?? ""
        country = p.country ?? ""
        phone = p.phone ?? ""
        website = p.website ?? ""
        rooms = p.roomCount.map(String.init) ?? ""
        propertyType = p.propertyType ?? ""
        goals = p.goals
    }

    private func save() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }
        if !rooms.trimmed.isEmpty, Int(rooms.trimmed) == nil {
            errorText = "Rooms must be a whole number."
            return
        }
        do {
            try await app.updateProfile([
                "name": .string(name.trimmed), "address": .from(address), "city": .from(city), "country": .from(country),
                "phone": .from(phone), "website": .from(website), "propertyType": .from(propertyType),
                "roomCount": .from(Int(rooms.trimmed)), "goals": .from(goals),
            ])
            await app.refreshOverview()
            dismiss()
        } catch {
            errorText = error.userMessage
        }
    }
}

struct LocaleEditView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var currency = "USD"
    @State private var timeZone = TimeZone.current.identifier
    @State private var showZones = false
    @State private var errorText: String?
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LocaleFields(currency: $currency, timeZone: $timeZone, showZones: $showZones)
                    .disabled(!app.canEdit)
                if currency != app.profile?.currency {
                    InlineMessage(kind: .warning, text: "Changing currency clears stored public rates so they can be fetched again in the new currency. Your performance data isn't converted.")
                }
                if let errorText { InlineMessage(kind: .error, text: errorText) }
                if app.canEdit {
                    Button("Save") { Task { await save() } }.buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(Metrics.margin)
        }
        .background(AppBackground())
        .navigationTitle("Currency & time")
        .sheet(isPresented: $showZones) { TimeZonePickerSheet(selection: $timeZone) }
        .onAppear {
            guard !loaded, let p = app.profile else { return }
            loaded = true
            currency = p.currency
            timeZone = p.timeZone
        }
    }

    private func save() async {
        do {
            try await app.updateProfile(["currency": .string(currency), "timeZone": .string(timeZone)])
            await app.refreshOverview()
            dismiss()
        } catch {
            errorText = error.userMessage
        }
    }
}
