import Charts
import SwiftUI

struct MarketView: View {
    @Environment(AppModel.self) private var app
    @State private var market: MarketResponse?
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var errorText: String?
    @State private var infoText: String?
    @State private var selectedDay: MarketDay?

    private var pricedDays: [MarketDay] { market?.days.filter { $0.compMedian != nil || $0.ownLowest != nil } ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                OrevBubble(state: orevState, title: headline, message: subline, size: 72)
                if let m = market {
                    providerNote(m)
                    if !pricedDays.isEmpty {
                        chart(m)
                        SectionHeader(title: "By stay date", subtitle: "Lowest public price per night, 2 adults. Tap a date for details or to enter a rate.")
                        VStack(spacing: 0) {
                            ForEach(m.days) { day in
                                Button { selectedDay = day } label: { MarketDayRow(day: day, currency: m.currency) }
                                    .buttonStyle(.plain)
                                if day.id != m.days.last?.id { Divider().overlay(Palette.hairline) }
                            }
                        }
                        .card(padding: 8)
                    } else {
                        emptyState(m)
                    }
                    competitorsCard(m)
                }
                if let infoText { InlineMessage(kind: .info, text: infoText) }
                if let errorText {
                    InlineMessage(kind: .error, text: errorText, actionTitle: "Try again") { Task { await load() } }
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.bottom, 24)
        }
        .background(AppBackground())
        .navigationTitle("Market")
        .toolbar {
            if app.canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        if isRefreshing { ProgressView() } else { Label("Refresh rates", systemImage: "arrow.clockwise") }
                    }
                    .disabled(isRefreshing)
                }
            }
        }
        .refreshable { await load() }
        .task(id: app.dataVersion) { await load() }
        .sheet(item: $selectedDay) { day in
            if let m = market {
                MarketDaySheet(day: day, market: m) { Task { await load() } }
                    .presentationDetents([.medium, .large])
                    .presentationContentInteraction(.scrolls)
            }
        }
    }

    private var orevState: OrevState {
        if isLoading && market == nil || isRefreshing { return .thinking }
        if errorText != nil { return .errorRecovery }
        if pricedDays.contains(where: { ($0.positionVsMedian ?? 0) <= -0.15 }) { return .opportunity }
        return pricedDays.isEmpty ? .uncertainty : .explaining
    }

    private var headline: String {
        guard let m = market else { return "Reading the market…" }
        let withPos = m.days.compactMap(\.positionVsMedian)
        guard !withPos.isEmpty else { return pricedDays.isEmpty ? "Not enough public rates yet" : "Here's the market" }
        let avg = withPos.reduce(0, +) / Double(withPos.count)
        if abs(avg) < 0.03 { return "You're priced in line with the market" }
        return avg < 0 ? "You're \(Fmt.percent(abs(avg))) below the market median" : "You're \(Fmt.percent(avg)) above the market median"
    }

    private var subline: String? {
        guard let m = market else { return nil }
        return "Averaged across \(m.days.filter { $0.positionVsMedian != nil }.count) dates with both your rate and competitors'. Updated \(Fmt.relative(ms: m.lastRefreshAt))."
    }

    private func providerNote(_ m: MarketResponse) -> some View {
        HStack(alignment: .top, spacing: 10) {
            BasisBadge(basis: "market")
            Text("Lowest public prices on listed travel sites via \(m.provider). Coverage is partial and doesn't include your restrictions or room mix. Refreshes: \(m.refresh.usedToday)/\(m.refresh.perDay) today.")
                .font(.caption).foregroundStyle(Palette.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func chart(_ m: MarketResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your rate vs. competitor median").font(.headline).foregroundStyle(Palette.ink)
            Chart {
                ForEach(m.days) { d in
                    if let lo = d.compLowest, let hi = d.compHighest {
                        AreaMark(x: .value("Date", Fmt.chartDate(d.stayDate)), yStart: .value("Low", lo), yEnd: .value("High", hi))
                            .foregroundStyle(Palette.teal.opacity(0.14))
                    }
                    if let med = d.compMedian {
                        LineMark(x: .value("Date", Fmt.chartDate(d.stayDate)), y: .value("Rate", med), series: .value("Series", "Market median"))
                            .foregroundStyle(Palette.teal)
                            .interpolationMethod(.monotone)
                    }
                    if let own = d.ownLowest {
                        LineMark(x: .value("Date", Fmt.chartDate(d.stayDate)), y: .value("Rate", own), series: .value("Series", "You"))
                            .foregroundStyle(Palette.gold)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        PointMark(x: .value("Date", Fmt.chartDate(d.stayDate)), y: .value("Rate", own))
                            .foregroundStyle(Palette.gold)
                            .symbolSize(24)
                    }
                }
            }
            .chartForegroundStyleScale(["Market median": Palette.teal, "You": Palette.gold])
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 200)
            .accessibilityLabel("Chart of your lowest public rate compared with the competitor median by date")
            Text("Shaded band: lowest to highest competitor rate.").font(.caption).foregroundStyle(Palette.inkTertiary)
        }
        .card()
    }

    private func emptyState(_ m: MarketResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No public rates yet").font(.headline).foregroundStyle(Palette.ink)
            Text(m.competitors.isEmpty
                 ? "Add competitors in Property → Competitors, then refresh."
                 : "Refresh to fetch public rates, or tap a date to enter a rate yourself. Hotels added by name only have manual rates.")
                .font(.subheadline).foregroundStyle(Palette.inkSecondary)
            if app.canEdit {
                Button("Refresh now") { Task { await refresh() } }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isRefreshing || m.refresh.remainingToday == 0)
            }
        }
        .card()
    }

    private func competitorsCard(_ m: MarketResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tracked hotels").font(.headline).foregroundStyle(Palette.ink)
                Spacer()
                Button("Manage") { app.selectedTab = .property }
                    .font(.footnote.weight(.semibold))
                    .frame(minHeight: 44)
            }
            HStack {
                Label(app.profile?.xoteloName ?? "Your property", systemImage: "house.fill")
                    .foregroundStyle(Palette.gold)
                Spacer()
                Text(m.ownTracked ? "Listing matched" : "No public listing").font(.caption).foregroundStyle(Palette.inkTertiary)
            }
            .font(.subheadline)
            ForEach(m.competitors) { c in
                HStack {
                    Label(c.name, systemImage: c.active ? "building.2" : "pause.circle")
                        .foregroundStyle(c.active ? Palette.ink : Palette.inkTertiary)
                    Spacer()
                    Text(!c.active ? "Paused on plan" : c.hasData ? "Has rates" : "No rates yet")
                        .font(.caption).foregroundStyle(Palette.inkTertiary)
                }
                .font(.subheadline)
            }
        }
        .card()
    }

    private func load() async {
        guard app.propertyId != nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let horizon = app.plan?.limits.rateHorizonDays ?? 14
            market = try await app.api.get(app.path("/market"), query: ["start": app.today, "end": Fmt.addDays(app.today, min(29, horizon - 1))])
            errorText = nil
        } catch is CancellationError {
        } catch {
            errorText = error.userMessage
        }
    }

    private func refresh() async {
        isRefreshing = true
        infoText = nil
        errorText = nil
        defer { isRefreshing = false }
        do {
            let info: RefreshInfo = try await app.api.post(app.path("/market/refresh"))
            infoText = info.inProgress ? "Fetching rates — \(info.pending) lookups left. They'll appear here as they arrive." : "Rates updated."
            await load()
            app.dataChanged()
        } catch {
            errorText = error.userMessage
        }
    }
}

private struct MarketDayRow: View {
    let day: MarketDay
    let currency: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Fmt.weekdayShort(day.stayDate)).font(.caption.weight(.semibold)).foregroundStyle(Palette.inkTertiary)
                Text(Fmt.dayNumber(day.stayDate)).font(.title3.weight(.bold)).foregroundStyle(Palette.ink)
            }
            .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("You \(Fmt.money(day.ownLowest, currency))").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                Text(day.compCount == 0 ? "No competitor rates" : "Median \(Fmt.money(day.compMedian, currency)) · \(day.compCount) hotel\(day.compCount == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(Palette.inkSecondary)
            }
            Spacer()
            if let pos = day.positionVsMedian {
                Text(pos.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always())))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(pos <= -0.1 ? Palette.gold : pos >= 0.1 ? Palette.coral : Palette.sage)
                    .accessibilityLabel(pos < 0 ? "\(Fmt.percent(abs(pos))) below median" : "\(Fmt.percent(pos)) above median")
            }
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Palette.inkTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

private struct MarketDaySheet: View {
    let day: MarketDay
    let market: MarketResponse
    var onChange: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var editing: String?
    @State private var rateText = ""
    @State private var errorText: String?

    private var hotels: [(id: String, name: String)] {
        [("own", app.profile?.xoteloName ?? "Your property")] + market.competitors.map { ($0.id, $0.name) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(hotels, id: \.id) { h in
                        let cell = market.byHotel[h.id]?[day.stayDate]
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(h.name).font(.subheadline.weight(h.id == "own" ? .bold : .regular))
                                if let cell {
                                    Text("\(cell.manual ? "Entered manually" : cell.channel) · \(Fmt.relative(ms: cell.observedAt))")
                                        .font(.caption).foregroundStyle(Palette.inkTertiary)
                                }
                            }
                            Spacer()
                            Text(Fmt.money(cell?.rate, market.currency)).font(.subheadline.weight(.semibold))
                            if app.canEdit {
                                Button {
                                    editing = h.id
                                    rateText = cell.map { String(format: "%.0f", $0.rate) } ?? ""
                                } label: { Image(systemName: "pencil").frame(width: 36, height: 36) }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Enter rate for \(h.name)")
                            }
                        }
                    }
                } footer: {
                    Text("Manual rates are labelled and replace public rates for that date until the next refresh.")
                }
                if let errorText { Section { Text(errorText).foregroundStyle(Palette.coral) } }
            }
            .navigationTitle(Fmt.longDay(day.stayDate))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert("Enter rate", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
                TextField("Rate in \(market.currency)", text: $rateText).keyboardType(.decimalPad)
                Button("Save") { Task { await save() } }
                Button("Remove manual rate", role: .destructive) { Task { await save(remove: true) } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Lowest rate for one night, 2 adults.")
            }
        }
    }

    private func save(remove: Bool = false) async {
        guard let hotel = editing else { return }
        editing = nil
        do {
            let rate: JSONValue = remove ? .null : .from(Fmt.parseNumber(rateText))
            let _: OKResponse = try await app.api.post(app.path("/market/manual-rate"), json: ["hotel": .string(hotel), "stayDate": .string(day.stayDate), "rate": rate])
            app.dataChanged()
            onChange()
            dismiss()
        } catch {
            errorText = error.userMessage
        }
    }
}
