import SwiftUI

struct ConfirmDetailsStep: View {
    @Environment(AppModel.self) private var app
    @State private var name = ""
    @State private var address = ""
    @State private var city = ""
    @State private var country = ""
    @State private var phone = ""
    @State private var propertyType = ""
    @State private var stars = ""
    @State private var summary = ""
    @State private var amenities: [String] = []
    @State private var selectedAmenities: Set<String> = []
    @State private var loaded = false
    @State private var isWorking = false
    @State private var errorText: String?

    private var fields: ExtractionFields? { app.extraction?.fields }

    var body: some View {
        StepScaffold(
            orev: isWorking ? .thinking : (app.extraction == nil ? .listening : .explaining),
            title: app.extraction == nil ? "Tell me about your property" : "Here's what I found",
            message: app.extraction == nil
                ? "Fill in what you know. Anything left blank stays blank — I won't guess."
                : "Please check each detail. I've marked where every value came from. Anything I couldn't find is left blank.",
            primaryTitle: "Looks right",
            primaryEnabled: !name.trimmed.isEmpty,
            isWorking: isWorking,
            onPrimary: { Task { await save() } }
        ) {
            if let warnings = app.extraction?.warnings, !warnings.isEmpty {
                InlineMessage(kind: .warning, text: warnings.joined(separator: " "))
            }
            VStack(alignment: .leading, spacing: 16) {
                LabeledField(label: "Property name", text: $name, note: note(fields?.name, current: name))
                LabeledField(label: "Address", text: $address, axis: .vertical, note: note(fields?.address, current: address))
                HStack(alignment: .top, spacing: 12) {
                    LabeledField(label: "City", text: $city, note: note(fields?.city, current: city))
                    LabeledField(label: "Country", text: $country, note: note(fields?.country, current: country))
                }
                LabeledField(label: "Phone", text: $phone, keyboard: .phonePad, note: note(fields?.phone, current: phone))
                HStack(alignment: .top, spacing: 12) {
                    LabeledField(label: "Property type", text: $propertyType, prompt: "Hotel, B&B…", note: note(fields?.propertyType, current: propertyType))
                    LabeledField(label: "Official stars", text: $stars, prompt: "Optional", keyboard: .decimalPad, note: numberNote(fields?.starRating, current: stars))
                }
                LabeledField(label: "Short description", text: $summary, prompt: "Optional", axis: .vertical, note: note(fields?.description, current: summary))
            }
            .card()

            if !amenities.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Amenities").font(.headline).foregroundStyle(Palette.ink)
                    Text("Tap to remove any that aren't right.").font(.footnote).foregroundStyle(Palette.inkTertiary)
                    FlowChips(items: amenities, selected: $selectedAmenities)
                }
                .card()
            }

            if let errorText { InlineMessage(kind: .error, text: errorText) }
        }
        .onAppear(perform: load)
    }

    private func note(_ field: ExtractedString?, current: String) -> FieldSourceNote? {
        guard let field, field.value.trimmed == current.trimmed, !current.trimmed.isEmpty else { return nil }
        return FieldSourceNote(confidence: field.confidence, evidence: field.evidence)
    }

    private func numberNote(_ field: ExtractedNumber?, current: String) -> FieldSourceNote? {
        guard let field, let v = Fmt.parseNumber(current), v == field.value else { return nil }
        return FieldSourceNote(confidence: field.confidence, evidence: field.evidence)
    }

    private func load() {
        guard !loaded, let p = app.profile else { return }
        loaded = true
        let f = fields
        name = p.name
        address = p.address ?? f?.address?.value ?? ""
        city = p.city ?? f?.city?.value ?? ""
        country = p.country ?? f?.country?.value ?? ""
        phone = p.phone ?? f?.phone?.value ?? ""
        propertyType = p.propertyType ?? f?.propertyType?.value ?? ""
        if let s = p.starRating ?? f?.starRating?.value { stars = s.formatted() }
        summary = p.description ?? f?.description?.value ?? ""
        amenities = p.amenities.isEmpty ? (f?.amenities?.value ?? []) : p.amenities
        selectedAmenities = Set(amenities)
    }

    private func source(for field: String, matches: Bool, confidence: String?) -> (String, JSONValue)? {
        guard matches, let confidence, let url = app.extraction?.sourceUrl else { return nil }
        return (field, ["source": "website", "confidence": .string(confidence), "url": .string(url)])
    }

    private func save() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }
        let f = fields
        var sources: [String: JSONValue] = [:]
        let checks: [(String, String, ExtractedString?)] = [
            ("address", address, f?.address), ("city", city, f?.city), ("country", country, f?.country),
            ("phone", phone, f?.phone), ("propertyType", propertyType, f?.propertyType), ("description", summary, f?.description),
        ]
        for (key, value, extracted) in checks {
            if let pair = source(for: key, matches: extracted?.value.trimmed == value.trimmed && !value.trimmed.isEmpty, confidence: extracted?.confidence) {
                sources[pair.0] = pair.1
            }
        }
        let starValue = Fmt.parseNumber(stars)
        if stars.trimmed.nilIfEmpty != nil, starValue == nil || !(1...7).contains(starValue ?? 0) {
            errorText = "Star rating must be a number from 1 to 7, or left blank."
            return
        }
        let kept = amenities.filter { selectedAmenities.contains($0) }
        if !kept.isEmpty, let amen = f?.amenities, let url = app.extraction?.sourceUrl {
            sources["amenities"] = ["source": "website", "confidence": .string(amen.confidence), "url": .string(url)]
        }
        do {
            try await app.updateProfile([
                "name": .string(name.trimmed),
                "address": .from(address),
                "city": .from(city),
                "country": .from(country),
                "phone": .from(phone),
                "propertyType": .from(propertyType),
                "starRating": .from(starValue),
                "description": .from(summary),
                "amenities": .from(kept),
                "fieldSources": .object(sources),
            ])
            app.goTo(.rooms)
        } catch {
            errorText = error.userMessage
        }
    }
}

/// Wrapping toggle chips.
struct FlowChips: View {
    let items: [String]
    @Binding var selected: Set<String>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                let on = selected.contains(item)
                Button {
                    if on { selected.remove(item) } else { selected.insert(item) }
                } label: {
                    Label(item, systemImage: on ? "checkmark" : "plus")
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(ChipButtonStyle(isSelected: on))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }
}
