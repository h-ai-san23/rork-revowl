import SwiftUI

struct CalendarView: View {
    @Environment(AppModel.self) private var app
    @State private var events: [EventRow] = []
    @State private var performance: [String: PerformanceRow] = [:]
    @State private var horizon = 30
    @State private var lastDiscovery: Double?
    @State private var selectedDate: String?
    @State private var isLoading = false
    @State private var isDiscovering = false
    @State private var errorText: String?
    @State private var infoText: String?
    @State private var showAdd = false
    @State private var showDismissed = false

    private var days: [String] { (0..<min(horizon, 42)).map { Fmt.addDays(app.today, $0) } }

    private var visibleEvents: [EventRow] {
        events.filter { e in
            (showDismissed || e.status != "dismissed") && (selectedDate.map { e.covers($0) } ?? true)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                OrevBubble(
                    state: isDiscovering ? .thinking : (errorText != nil ? .errorRecovery : (events.isEmpty ? .uncertainty : .explaining)),
                    title: events.isEmpty ? "No events on your calendar yet" : "\(events.filter { $0.status != "dismissed" }.count) events in the next \(horizon) days",
                    message: "I search the web for events with a published source. Treat unverified events with care until you confirm them.",
                    size: 72
                )
                dayStrip
                HStack {
                    SectionHeader(title: selectedDate.map { Fmt.longDay($0) } ?? "Upcoming", subtitle: "Last checked \(Fmt.relative(ms: lastDiscovery))")
                    if selectedDate != nil {
                        Button("Show all") { selectedDate = nil }.font(.footnote.weight(.semibold)).frame(minHeight: 44)
                    }
                }
                if let date = selectedDate, let perf = performance[date] {
                    HStack {
                        BasisBadge(basis: perf.source == "sample" ? "sample" : perf.kind)
                        Text("\(perf.roomsSold) of \(perf.roomsAvailable) rooms · \(Fmt.percent(perf.occupancy))")
                            .font(.subheadline).foregroundStyle(Palette.ink)
                    }
                    .card(padding: 12)
                }
                if visibleEvents.isEmpty && !isLoading {
                    Text(selectedDate == nil ? "Nothing found yet. Tap “Find events” or add one you know about." : "No events on this date.")
                        .font(.subheadline).foregroundStyle(Palette.inkSecondary)
                        .card()
                }
                ForEach(visibleEvents) { e in
                    EventCard(event: e, canEdit: app.canEdit) { status in
                        Task { await setStatus(e, status) }
                    } onDelete: {
                        Task { await delete(e) }
                    } onAsk: {
                        app.ask("How might \(e.title) on \(Fmt.day(e.startDate)) affect my demand and pricing?")
                    }
                }
                Toggle("Show dismissed", isOn: $showDismissed).font(.subheadline).tint(Palette.teal)
                if let infoText { InlineMessage(kind: .info, text: infoText) }
                if let errorText { InlineMessage(kind: .error, text: errorText) }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 24)
        }
        .background(AppBackground())
        .navigationTitle("Calendar")
        .toolbar {
            if app.canEdit {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { Task { await discover() } } label: {
                        if isDiscovering { ProgressView() } else { Label("Find events", systemImage: "sparkle.magnifyingglass") }
                    }
                    .disabled(isDiscovering)
                    Button { showAdd = true } label: { Label("Add event", systemImage: "plus") }
                }
            }
        }
        .refreshable { await load() }
        .task(id: app.dataVersion) { await load() }
        .sheet(isPresented: $showAdd) { AddEventSheet { Task { await load() } } }
    }

    private var dayStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { d in
                    let count = events.filter { $0.status != "dismissed" && $0.covers(d) }.count
                    let occ = performance[d]?.occupancy
                    let isSel = selectedDate == d
                    Button { selectedDate = isSel ? nil : d } label: {
                        VStack(spacing: 4) {
                            Text(Fmt.weekdayShort(d)).font(.caption2.weight(.semibold))
                            Text(Fmt.dayNumber(d)).font(.headline)
                            HStack(spacing: 2) {
                                ForEach(0..<min(count, 3), id: \.self) { _ in Circle().fill(isSel ? Palette.onAccent : Palette.gold).frame(width: 5, height: 5) }
                            }
                            .frame(height: 5)
                            Capsule().fill(isSel ? Palette.onAccent.opacity(0.3) : Palette.hairline)
                                .frame(width: 30, height: 4)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(isSel ? Palette.onAccent : Palette.teal).frame(width: 30 * CGFloat(occ ?? 0), height: 4)
                                }
                        }
                        .foregroundStyle(isSel ? Palette.onAccent : Palette.ink)
                        .frame(width: 52, height: 84)
                        .background(isSel ? Palette.teal : Palette.surface, in: .rect(cornerRadius: 14))
                        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.hairline, lineWidth: isSel ? 0 : 1) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(Fmt.longDay(d)), \(count) events\(occ.map { ", \(Fmt.percent($0)) on the books" } ?? "")")
                    .accessibilityAddTraits(isSel ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: selectedDate)
    }

    private func load() async {
        guard app.propertyId != nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let res: EventsResponse = try await app.api.get(app.path("/events"))
            events = res.events
            horizon = res.horizonDays
            lastDiscovery = res.lastDiscoveryAt
            let perf: PerformanceResponse = try await app.api.get(app.path("/performance"), query: ["start": app.today, "end": Fmt.addDays(app.today, 45)])
            var map: [String: PerformanceRow] = [:]
            for r in perf.rows { map[r.date] = r }
            performance = map
            errorText = nil
        } catch is CancellationError {
        } catch {
            errorText = error.userMessage
        }
    }

    private func discover() async {
        isDiscovering = true
        errorText = nil
        infoText = nil
        defer { isDiscovering = false }
        do {
            let res: DiscoverResult = try await app.api.post(app.path("/events/discover"))
            infoText = res.skipped ? (res.message ?? "Events were checked recently.") : "Found \(res.found ?? 0) events, \(res.added) new."
            await load()
            app.dataChanged()
        } catch {
            errorText = error.userMessage
        }
    }

    private func setStatus(_ e: EventRow, _ status: String) async {
        do {
            let _: OKResponse = try await app.api.patch(app.path("/events/\(e.id)"), json: ["status": .string(status)])
            await load()
            app.dataChanged()
        } catch {
            errorText = error.userMessage
        }
    }

    private func delete(_ e: EventRow) async {
        do {
            let _: OKResponse = try await app.api.delete(app.path("/events/\(e.id)"))
            await load()
            app.dataChanged()
        } catch {
            errorText = error.userMessage
        }
    }
}

private struct EventCard: View {
    let event: EventRow
    let canEdit: Bool
    var onStatus: (String) -> Void
    var onDelete: () -> Void
    var onAsk: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title).font(.headline).foregroundStyle(event.status == "dismissed" ? Palette.inkTertiary : Palette.ink)
                    Text([Fmt.range(event.startDate, event.endDate), event.venue].compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(Palette.inkSecondary)
                }
                Spacer()
                statusPill
            }
            HStack(spacing: 6) {
                Pill(text: event.category.capitalized, tint: Palette.inkSecondary, fill: Palette.surfaceRaised)
                if let a = event.expectedAttendance {
                    Pill(text: "~\(Fmt.number(a)) people (per source)", tint: Palette.inkSecondary, fill: Palette.surfaceRaised)
                }
            }
            if let s = event.sourceUrl, let url = URL(string: s) {
                Link(destination: url) {
                    Label(event.sourceTitle ?? url.host() ?? "Source", systemImage: event.sourceReachable ? "link" : "link.badge.plus")
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(Palette.teal)
                if !event.sourceReachable {
                    Text("We couldn't open this source when we checked.").font(.caption).foregroundStyle(Palette.coral)
                }
            }
            HStack(spacing: 8) {
                if canEdit && event.status == "unverified" {
                    Button("Confirm") { onStatus("confirmed") }.buttonStyle(.glassProminent).tint(Palette.teal)
                    Button("Dismiss") { onStatus("dismissed") }.buttonStyle(.glass)
                }
                if canEdit && event.status == "dismissed" {
                    Button("Restore") { onStatus("unverified") }.buttonStyle(.glass)
                }
                Spacer()
                Menu {
                    Button("Ask Orev about this", systemImage: "bubble.left", action: onAsk)
                    if canEdit {
                        if event.status == "confirmed" { Button("Mark unverified", systemImage: "questionmark.circle") { onStatus("unverified") } }
                        Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                    }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                }
                .accessibilityLabel("More actions for \(event.title)")
            }
            .font(.footnote.weight(.semibold))
        }
        .card()
    }

    private var statusPill: some View {
        switch event.status {
        case "confirmed": Pill(text: "Confirmed", icon: "checkmark.seal.fill", tint: Palette.sage, fill: Palette.sageSoft)
        case "dismissed": Pill(text: "Dismissed", tint: Palette.inkTertiary, fill: Palette.surfaceRaised)
        default: Pill(text: "Unverified", icon: "questionmark.circle", tint: Palette.gold, fill: Palette.goldSoft)
        }
    }
}

private struct AddEventSheet: View {
    var onSaved: () -> Void
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var start = Date.now
    @State private var end = Date.now
    @State private var venue = ""
    @State private var source = ""
    @State private var category = "other"
    @State private var errorText: String?
    @State private var isWorking = false

    private let categories = ["conference", "sports", "concert", "festival", "holiday", "exhibition", "community", "other"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Event name", text: $title)
                    DatePicker("Starts", selection: $start, displayedComponents: .date)
                    DatePicker("Ends", selection: $end, in: start..., displayedComponents: .date)
                    Picker("Type", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                }
                Section {
                    TextField("Venue (optional)", text: $venue)
                    TextField("Source link (optional)", text: $source)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                } footer: {
                    Text("Events you add are marked confirmed.")
                }
                if let errorText { Section { Text(errorText).foregroundStyle(Palette.coral) } }
            }
            .navigationTitle("Add event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(title.trimmed.isEmpty || isWorking)
                }
            }
        }
    }

    private func save() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let _: EventRow = try await app.api.post(app.path("/events"), json: [
                "title": .string(title.trimmed),
                "startDate": .string(Fmt.localISO(start)),
                "endDate": .string(Fmt.localISO(max(start, end))),
                "venue": .from(venue),
                "sourceUrl": .from(source),
                "category": .string(category),
            ])
            app.dataChanged()
            onSaved()
            dismiss()
        } catch {
            errorText = error.userMessage
        }
    }
}
