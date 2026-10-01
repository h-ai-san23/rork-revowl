import SwiftUI

struct CompetitorsStep: View {
    @Environment(AppModel.self) private var app
    @State private var match: MatchResult?
    @State private var existing: [Competitor] = []
    @State private var listingKey: String?
    @State private var listingName: String?
    @State private var picks: [HotelCandidate] = []
    @State private var manualName = ""
    @State private var isLoading = false
    @State private var isWorking = false
    @State private var errorText: String?
    @State private var loaded = false

    private let maxPicks = 9

    private var ownCandidates: [HotelCandidate] {
        (match?.candidates ?? []).filter { $0.matchScore >= 0.25 }.prefix(4).map { $0 }
    }

    private var nearby: [HotelCandidate] {
        let taken = Set(existing.compactMap(\.xoteloKey))
        return (match?.nearby ?? []).filter { $0.key != listingKey && !taken.contains($0.key) }
    }

    var body: some View {
        StepScaffold(
            orev: isLoading || isWorking ? .thinking : (picks.isEmpty && existing.isEmpty ? .listening : .opportunity),
            title: "Who do you compete with?",
            message: "Pick the hotels your guests compare you with. I'll watch their lowest public rates. Your plan decides how many are refreshed: Essentials 1, Insight 5, Horizon 9 — I'll keep your picks in order.",
            primaryTitle: picks.isEmpty ? "Continue" : "Save \(picks.count) competitor\(picks.count == 1 ? "" : "s")",
            isWorking: isWorking,
            onPrimary: { Task { await save() } }
        ) {
            if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Looking up your public listing and nearby hotels…")
                        .font(.subheadline).foregroundStyle(Palette.inkSecondary)
                }
                .card()
            }

            if !ownCandidates.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Is this your public listing?").font(.headline).foregroundStyle(Palette.ink)
                    Text("Confirming it lets me compare your public rate with the market.")
                        .font(.footnote).foregroundStyle(Palette.inkTertiary)
                    ForEach(ownCandidates) { c in
                        HotelCandidateRow(hotel: c, currency: app.currency, isSelected: listingKey == c.key) {
                            if listingKey == c.key {
                                listingKey = nil
                                listingName = nil
                            } else {
                                listingKey = c.key
                                listingName = c.name
                                picks.removeAll { $0.key == c.key }
                            }
                        }
                    }
                    Button(listingKey == nil ? "None of these is mine" : "Clear selection") {
                        listingKey = nil
                        listingName = nil
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.teal)
                    .frame(minHeight: 44)
                }
                .card()
            }

            if !existing.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Already tracking").font(.headline).foregroundStyle(Palette.ink)
                    ForEach(existing) { c in
                        Label(c.name, systemImage: c.active ? "checkmark.circle.fill" : "pause.circle")
                            .font(.subheadline).foregroundStyle(Palette.ink)
                    }
                }
                .card()
            }

            if !nearby.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Nearby hotels").font(.headline).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(picks.count) of \(maxPicks)").font(.footnote.weight(.semibold)).foregroundStyle(Palette.inkTertiary)
                    }
                    ForEach(nearby.prefix(25)) { c in
                        let index = picks.firstIndex(where: { $0.key == c.key })
                        HotelCandidateRow(hotel: c, currency: app.currency, badge: index.map { "\($0 + 1)" }, isSelected: index != nil) {
                            toggle(c)
                        }
                        if c.id != nearby.prefix(25).last?.id { Divider().overlay(Palette.hairline) }
                    }
                }
                .card()
                .sensoryFeedback(.selection, trigger: picks.count)
            } else if !isLoading && loaded {
                InlineMessage(kind: .info, text: app.profile?.latitude == nil
                    ? "I don't have your property's location, so I can't suggest nearby hotels. Add competitors by name below."
                    : "I couldn't find nearby hotels with public rates. Add competitors by name below; you can enter their rates manually.")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Add by name").font(.headline).foregroundStyle(Palette.ink)
                HStack {
                    AppTextField(
                        placeholder: "Competitor name",
                        text: $manualName,
                        id: "competitors.manualName",
                        capitalization: .words,
                        submitLabel: .done,
                        onSubmit: { Task { await addManual() } }
                    )
                    Button("Add") { Task { await addManual() } }
                        .buttonStyle(.glass)
                        .frame(minHeight: 44)
                        .disabled(manualName.trimmed.count < 2 || isWorking)
                        .accessibilityIdentifier("competitors.add")
                }
                Text("Hotels added by name have no automatic rates — you can enter them yourself.")
                    .font(.caption).foregroundStyle(Palette.inkTertiary)
            }
            .card()

            if let errorText { InlineMessage(kind: .error, text: errorText) }
        }
        .task { await load() }
    }

    private func toggle(_ c: HotelCandidate) {
        if let i = picks.firstIndex(where: { $0.key == c.key }) {
            picks.remove(at: i)
        } else if picks.count + existing.count < maxPicks {
            picks.append(c)
        } else {
            errorText = "You can pick up to \(maxPicks) competitors."
        }
    }

    private func load() async {
        guard !loaded else { return }
        isLoading = true
        defer {
            isLoading = false
            loaded = true
        }
        listingKey = app.profile?.xoteloKey
        listingName = app.profile?.xoteloName
        if let list: CompetitorsResponse = try? await app.api.get(app.path("/competitors")) {
            existing = list.competitors
        }
        do {
            match = try await app.api.post(app.path("/match"))
            if listingKey == nil, let best = match?.candidates.first, best.matchScore >= 0.7 {
                listingKey = best.key
                listingName = best.name
            }
        } catch {
            errorText = "Nearby hotels couldn't be loaded (\(error.userMessage)) You can still add competitors by name."
        }
    }

    private func addManual() async {
        let name = manualName.trimmed
        guard name.count >= 2 else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let c: Competitor = try await app.api.post(app.path("/competitors"), json: ["name": .string(name)])
            existing.append(c)
            manualName = ""
            errorText = nil
        } catch {
            errorText = error.userMessage
        }
    }

    private func save() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }
        do {
            if listingKey != app.profile?.xoteloKey {
                let _: ListingResponse = try await app.api.post(app.path("/listing"), json: ["xoteloKey": .from(listingKey), "name": .from(listingName)])
            }
            for c in picks {
                let _: Competitor = try await app.api.post(app.path("/competitors"), json: [
                    "name": .string(c.name), "xoteloKey": .string(c.key),
                    "latitude": .from(c.latitude), "longitude": .from(c.longitude),
                    "distanceKm": .from(c.distanceKm), "rating": .from(c.rating),
                ])
            }
            picks = []
            app.dataChanged()
            app.goTo(.goals)
        } catch {
            errorText = error.userMessage
        }
    }
}
