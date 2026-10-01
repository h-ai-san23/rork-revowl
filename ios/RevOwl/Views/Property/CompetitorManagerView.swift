import SwiftUI

private struct CompetitorManageRow: View {
    let competitor: Competitor
    let isActive: Bool
    let canEdit: Bool
    let onToggle: () -> Void

    private var subtitle: String {
        guard competitor.xoteloKey != nil else { return "Manual rates only" }
        if let d = competitor.distanceKm { return String(format: "%.1f km away · Public listing", d) }
        return "Public listing"
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isActive ? Palette.teal : Palette.inkTertiary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .disabled(!canEdit)
            .accessibilityLabel(isActive ? "Tracked" : "Paused")
            VStack(alignment: .leading, spacing: 2) {
                Text(competitor.name).foregroundStyle(Palette.ink)
                Text(subtitle).font(.caption).foregroundStyle(Palette.inkTertiary)
            }
        }
    }
}

/// Manage competitors. When the list exceeds the plan limit, the user picks which stay active.
struct CompetitorManagerView: View {
    @Environment(AppModel.self) private var app
    @State private var competitors: [Competitor] = []
    @State private var limit = 1
    @State private var nearby: [HotelCandidate] = []
    @State private var activeIds: Set<String> = []
    @State private var manualName = ""
    @State private var isWorking = false
    @State private var errorText: String?
    @State private var showNearby = false

    private var savedActiveIds: Set<String> {
        var ids = Set<String>()
        for c in competitors where c.active {
            ids.insert(c.id)
        }
        return ids
    }

    private var activeChanged: Bool { activeIds != savedActiveIds }

    private var showUpgrade: Bool { competitors.count > limit || !(app.plan?.isPaid ?? false) }

    var body: some View {
        List {
            trackedSection
            if activeChanged && app.canEdit { saveSection }
            if app.canEdit { addSection }
            if app.canEdit && showNearby { nearbySection }
            if let errorText {
                Section { Text(errorText).foregroundStyle(Palette.coral) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Competitors")
        .toolbar {
            if showUpgrade {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Upgrade") { app.showPaywall = true }
                }
            }
        }
        .task(id: app.dataVersion) { await load() }
    }

    private var trackedSection: some View {
        Section {
            ForEach(competitors) { c in
                CompetitorManageRow(
                    competitor: c,
                    isActive: activeIds.contains(c.id),
                    canEdit: app.canEdit
                ) { toggle(c.id) }
            }
            .onDelete { offsets in
                if app.canEdit { delete(offsets) }
            }
            .deleteDisabled(!app.canEdit)
        } header: {
            Text("Tracked \(activeIds.count) of \(limit)")
        } footer: {
            Text("Your plan refreshes rates for \(limit) competitor\(limit == 1 ? "" : "s"). Paused hotels keep their history and switch back on when you upgrade.")
        }
    }

    private var saveSection: some View {
        Section {
            Button("Save tracked hotels") { Task { await saveActive() } }
                .disabled(activeIds.count > limit || isWorking)
            if activeIds.count > limit {
                Text("Choose up to \(limit).").foregroundStyle(Palette.coral)
            }
        }
    }

    private var addSection: some View {
        Section("Add") {
            HStack {
                TextField("Competitor name", text: $manualName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { Task { await addManual() } }
                    .accessibilityIdentifier("manageCompetitors.name")
                // Borderless so tapping the text field focuses it instead of firing this button
                // (a default-style Button inside a List row captures taps on the whole row).
                Button("Add") { Task { await addManual() } }
                    .buttonStyle(.borderless)
                    .disabled(manualName.trimmed.count < 2 || isWorking)
                    .accessibilityIdentifier("manageCompetitors.add")
            }
            Button("Suggest nearby hotels", systemImage: "location.magnifyingglass") {
                showNearby = true
                Task { await loadNearby() }
            }
            .accessibilityIdentifier("manageCompetitors.suggest")
        }
    }

    private var nearbySection: some View {
        Section("Nearby") {
            if nearby.isEmpty { ProgressView() }
            ForEach(Array(nearby.prefix(20))) { h in
                HotelCandidateRow(hotel: h, currency: app.currency, isSelected: false) {
                    Task { await add(h) }
                }
            }
        }
    }

    private func toggle(_ id: String) {
        if activeIds.contains(id) { activeIds.remove(id) } else { activeIds.insert(id) }
    }

    private func load() async {
        do {
            let res: CompetitorsResponse = try await app.api.get(app.path("/competitors"))
            competitors = res.competitors
            limit = res.limit
            activeIds = savedActiveIds
        } catch {
            errorText = error.userMessage
        }
    }

    private func loadNearby() async {
        do {
            let m: MatchResult = try await app.api.post(app.path("/match"))
            let taken = Set(competitors.compactMap(\.xoteloKey) + [app.profile?.xoteloKey].compactMap { $0 })
            nearby = m.nearby.filter { !taken.contains($0.key) }
            if nearby.isEmpty { errorText = "No nearby hotels with public listings were found." }
        } catch {
            errorText = error.userMessage
        }
    }

    private func add(_ h: HotelCandidate) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let _: Competitor = try await app.api.post(app.path("/competitors"), json: [
                "name": .string(h.name), "xoteloKey": .string(h.key), "latitude": .from(h.latitude),
                "longitude": .from(h.longitude), "distanceKm": .from(h.distanceKm), "rating": .from(h.rating),
            ])
            nearby.removeAll { $0.key == h.key }
            app.dataChanged()
            await load()
        } catch {
            errorText = error.userMessage
        }
    }

    private func addManual() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let _: Competitor = try await app.api.post(app.path("/competitors"), json: ["name": .string(manualName.trimmed)])
            manualName = ""
            app.dataChanged()
            await load()
        } catch {
            errorText = error.userMessage
        }
    }

    private func saveActive() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let _: CompetitorsResponse = try await app.api.post(app.path("/competitors/active"), json: ["ids": .from(Array(activeIds))])
            app.dataChanged()
            await load()
        } catch {
            errorText = error.userMessage
        }
    }

    private func delete(_ offsets: IndexSet) {
        let ids = offsets.map { competitors[$0].id }
        Task {
            for id in ids {
                let _: OKResponse? = try? await app.api.delete(app.path("/competitors/\(id)"))
            }
            app.dataChanged()
            await load()
        }
    }
}
