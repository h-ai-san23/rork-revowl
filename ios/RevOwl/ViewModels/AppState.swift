import SwiftUI

@Observable
class AppState {
    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    var hasCompletedSetup: Bool = UserDefaults.standard.bool(forKey: "hasCompletedSetup")
    var hotel: Hotel = Hotel()
    var competitors: [Competitor] = []
    var demandSignals: [DemandSignal] = []
    var recommendations: [Recommendation] = []
    var alerts: [AlertItem] = []
    var localEvents: [LocalEvent] = []
    var isRefreshingEvents: Bool = false
    var lastEventsRefresh: Date? = nil
    var eventsErrorMessage: String? = nil
    var occupancyEntries: [OccupancyEntry] = []
    var hotelRates: [HotelRateEntry] = []
    /// Synced from StoreViewModel entitlements (see ContentView). Scout when no subscription is active.
    var currentTier: SubscriptionTier = .scout
    var isRefreshingRates: Bool = false
    var lastRateRefresh: Date = .now
    var rateDisplayMode: RateDisplayMode = .perRoomType
    var isResolvingKeys: Bool = false

    let rateService = RateService()
    let eventsService = LocalEventsService()

    private static let hotelKey = "savedHotelData"
    private static let competitorsKey = "savedCompetitorsData"
    private static let hotelRatesKey = "savedHotelRatesData"
    private static let occupancyKey = "savedOccupancyData"
    private static let demandKey = "savedDemandData"
    private static let recommendationsKey = "savedRecommendationsData"
    private static let alertsKey = "savedAlertsData"
    private static let eventsKey = "savedLocalEventsData"
    private static let eventsRefreshKey = "savedLocalEventsRefresh"

    init() {
        loadPersistedData()
    }

    private func loadPersistedData() {
        let defaults = UserDefaults.standard
        let decoder = JSONDecoder()

        if defaults.bool(forKey: "hasCompletedSetup") {
            if let data = defaults.data(forKey: Self.hotelKey),
               let saved = try? decoder.decode(Hotel.self, from: data) {
                hotel = saved
            }
            if let data = defaults.data(forKey: Self.competitorsKey),
               let saved = try? decoder.decode([Competitor].self, from: data) {
                competitors = saved
            }
            if let data = defaults.data(forKey: Self.hotelRatesKey),
               let saved = try? decoder.decode([HotelRateEntry].self, from: data) {
                hotelRates = saved
            }
            if let data = defaults.data(forKey: Self.occupancyKey),
               let saved = try? decoder.decode([OccupancyEntry].self, from: data) {
                occupancyEntries = saved
            }
            if let data = defaults.data(forKey: Self.demandKey),
               let saved = try? decoder.decode([DemandSignal].self, from: data) {
                demandSignals = saved
            }
            if let data = defaults.data(forKey: Self.recommendationsKey),
               let saved = try? decoder.decode([Recommendation].self, from: data) {
                recommendations = saved
            }
            if let data = defaults.data(forKey: Self.alertsKey),
               let saved = try? decoder.decode([AlertItem].self, from: data) {
                alerts = saved
            }
            if let data = defaults.data(forKey: Self.eventsKey),
               let saved = try? decoder.decode([LocalEvent].self, from: data) {
                localEvents = saved
            }
            if let stamp = defaults.object(forKey: Self.eventsRefreshKey) as? Date {
                lastEventsRefresh = stamp
            }
        }
    }

    func persistData() {
        let defaults = UserDefaults.standard
        let encoder = JSONEncoder()

        if let data = try? encoder.encode(hotel) { defaults.set(data, forKey: Self.hotelKey) }
        if let data = try? encoder.encode(competitors) { defaults.set(data, forKey: Self.competitorsKey) }
        if let data = try? encoder.encode(hotelRates) { defaults.set(data, forKey: Self.hotelRatesKey) }
        if let data = try? encoder.encode(occupancyEntries) { defaults.set(data, forKey: Self.occupancyKey) }
        if let data = try? encoder.encode(demandSignals) { defaults.set(data, forKey: Self.demandKey) }
        if let data = try? encoder.encode(recommendations) { defaults.set(data, forKey: Self.recommendationsKey) }
        if let data = try? encoder.encode(alerts) { defaults.set(data, forKey: Self.alertsKey) }
        if let data = try? encoder.encode(localEvents) { defaults.set(data, forKey: Self.eventsKey) }
        if let stamp = lastEventsRefresh { defaults.set(stamp, forKey: Self.eventsRefreshKey) }
    }

    private func clearPersistedData() {
        let defaults = UserDefaults.standard
        for key in [Self.hotelKey, Self.competitorsKey, Self.hotelRatesKey, Self.occupancyKey, Self.demandKey, Self.recommendationsKey, Self.alertsKey, Self.eventsKey, Self.eventsRefreshKey] {
            defaults.removeObject(forKey: key)
        }
    }

    var unreadAlertCount: Int {
        alerts.filter { !$0.isRead }.count
    }

    var pendingRecommendationCount: Int {
        recommendations.filter { $0.status == .pending }.count
    }

    var demandScore: Int {
        let scores = demandSignals.map(\.score)
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / scores.count
    }

    var totalRoomsSold: Int {
        occupancyEntries.map(\.roomsSold).reduce(0, +)
    }

    var overallOccupancy: Double {
        Double(totalRoomsSold) / Double(max(hotel.totalRooms, 1))
    }

    var avgRate: Double {
        guard !hotelRates.isEmpty else {
            guard let first = hotel.roomTypes.first else { return 0 }
            return first.baseRate
        }
        let total = hotelRates.map(\.currentRate).reduce(0, +)
        return total / Double(hotelRates.count)
    }

    var competitorAvgRate: Double {
        let activeRates = competitors.filter { $0.currentRate > 0 }.map(\.currentRate)
        guard !activeRates.isEmpty else { return 0 }
        return activeRates.reduce(0, +) / Double(activeRates.count)
    }

    var revPAR: Double { avgRate * overallOccupancy }

    var dailyCurrentRevenue: Double {
        occupancyEntries.reduce(0) { total, entry in
            let rate = hotelRates.first(where: { $0.roomTypeId == entry.roomTypeId })?.currentRate
                ?? hotel.roomTypes.first(where: { $0.id == entry.roomTypeId })?.baseRate ?? 0
            return total + Double(entry.roomsSold) * rate
        }
    }

    var dailyOptimalRevenue: Double {
        occupancyEntries.reduce(0) { total, entry in
            if let rec = recommendations.first(where: { $0.roomTypeId == entry.roomTypeId && $0.status == .pending }) {
                return total + Double(entry.roomsSold) * rec.recommendedRate
            }
            let rate = hotelRates.first(where: { $0.roomTypeId == entry.roomTypeId })?.currentRate
                ?? hotel.roomTypes.first(where: { $0.id == entry.roomTypeId })?.baseRate ?? 0
            return total + Double(entry.roomsSold) * rate
        }
    }

    var dailyMissedRevenue: Double {
        dailyOptimalRevenue - dailyCurrentRevenue
    }

    func markAlertRead(_ id: String) {
        if let index = alerts.firstIndex(where: { $0.id == id }) {
            alerts[index].isRead = true
        }
    }

    func applyRecommendation(_ id: String) {
        if let index = recommendations.firstIndex(where: { $0.id == id }) {
            recommendations[index].status = .applied
            let rec = recommendations[index]
            if let rateIndex = hotelRates.firstIndex(where: { $0.roomTypeId == rec.roomTypeId }) {
                hotelRates[rateIndex].currentRate = rec.recommendedRate
                hotelRates[rateIndex].lastUpdated = .now
                hotelRates[rateIndex].source = .manual
            }
        }
    }

    func dismissRecommendation(_ id: String) {
        if let index = recommendations.firstIndex(where: { $0.id == id }) {
            recommendations[index].status = .dismissed
        }
    }

    func updateOccupancy(roomTypeId: String, roomsSold: Int) {
        if let index = occupancyEntries.firstIndex(where: { $0.roomTypeId == roomTypeId }) {
            occupancyEntries[index].roomsSold = roomsSold
        }
    }

    func updateHotelRate(roomTypeId: String, rate: Double, source: RateSource) {
        if let index = hotelRates.firstIndex(where: { $0.roomTypeId == roomTypeId }) {
            hotelRates[index].currentRate = rate
            hotelRates[index].source = source
            hotelRates[index].lastUpdated = .now
        }
    }

    func toggleRateDisplayMode() {
        rateDisplayMode = rateDisplayMode == .perRoomType ? .average : .perRoomType
    }

    // MARK: - Competitor Management

    /// Adds a discovered competitor, resolves its rate source key, and refreshes data.
    /// Returns false if the competitor already exists or the tier limit is reached.
    @discardableResult
    func addCompetitor(_ discovered: DiscoveredCompetitor) async -> Bool {
        let exists = competitors.contains { existing in
            existing.name.caseInsensitiveCompare(discovered.name) == .orderedSame
                || (abs(existing.latitude - discovered.latitude) < 0.0005
                    && abs(existing.longitude - discovered.longitude) < 0.0005)
        }
        guard !exists else { return false }
        guard competitors.count < currentTier.competitorLimit else { return false }

        let newCompetitor = Competitor(
            name: discovered.name,
            latitude: discovered.latitude,
            longitude: discovered.longitude,
            distance: discovered.distance,
            address: discovered.address
        )
        competitors.append(newCompetitor)
        persistData()

        isResolvingKeys = true
        let resolved = await rateService.resolveXoteloKeys(for: competitors)
        competitors = resolved
        isResolvingKeys = false
        persistData()

        await refreshRates()
        updateDemandSignalsFromCompetitors()
        regenerateRecommendations()
        persistData()
        return true
    }

    /// Removes a competitor and refreshes derived signals.
    func removeCompetitor(_ id: String) {
        competitors.removeAll { $0.id == id }
        updateDemandSignalsFromCompetitors()
        regenerateRecommendations()
        persistData()
    }

    func resolveCompetitorKeysAndRefresh() async {
        isResolvingKeys = true

        let hotelKey = await rateService.resolveHotelXoteloKey(hotel: hotel)
        if !hotelKey.isEmpty && hotel.xoteloKey.isEmpty {
            hotel.xoteloKey = hotelKey
        }

        let resolved = await rateService.resolveXoteloKeys(for: competitors)
        competitors = resolved
        isResolvingKeys = false

        persistData()
        await refreshRates()
        updateDemandSignalsFromCompetitors()
        regenerateRecommendations()
        persistData()

        let unresolvedCount = competitors.filter({ $0.xoteloKey.isEmpty }).count
        if unresolvedCount > 0 || hotel.xoteloKey.isEmpty {
            try? await Task.sleep(for: .seconds(3))
            isResolvingKeys = true
            if hotel.xoteloKey.isEmpty {
                let retryKey = await rateService.resolveHotelXoteloKey(hotel: hotel)
                if !retryKey.isEmpty { hotel.xoteloKey = retryKey }
            }
            let retryResolved = await rateService.resolveXoteloKeys(for: competitors)
            competitors = retryResolved
            isResolvingKeys = false
            persistData()
            await refreshRates()
            updateDemandSignalsFromCompetitors()
            regenerateRecommendations()
            persistData()
        }
    }

    func refreshLocalEvents() async {
        guard !isRefreshingEvents else { return }
        isRefreshingEvents = true
        eventsErrorMessage = nil
        defer { isRefreshingEvents = false }

        let city = Self.cityFromAddress(hotel.address)
        do {
            let events = try await eventsService.fetchUpcomingEvents(
                city: city,
                latitude: hotel.latitude,
                longitude: hotel.longitude
            )
            localEvents = events.sorted { $0.date < $1.date }
            lastEventsRefresh = .now
            updateEventsDemandSignal()
            persistData()
        } catch {
            switch error {
            case LocalEventsError.authError:
                eventsErrorMessage = "Events search is currently unavailable. Please restart the app."
            case LocalEventsError.insufficientBalance:
                eventsErrorMessage = "Events search is temporarily unavailable."
            case LocalEventsError.rateLimited:
                eventsErrorMessage = "Too many requests. Please try again in a moment."
            case LocalEventsError.parseFailure:
                eventsErrorMessage = "Couldn't read event results. Please try again."
            default:
                eventsErrorMessage = "Couldn't load events. Check your connection and try again."
            }
        }
    }

    private static func cityFromAddress(_ address: String) -> String {
        let parts = address.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count >= 2 {
            return parts.dropFirst().prefix(2).joined(separator: ", ")
        }
        return address
    }

    private func updateEventsDemandSignal() {
        guard !localEvents.isEmpty else { return }
        let now = Date()
        let in14 = now.addingTimeInterval(60 * 60 * 24 * 14)
        let near = localEvents.filter { $0.date >= now && $0.date <= in14 }
        guard !near.isEmpty else { return }

        let highImpact = near.filter { $0.impact == .high }.count
        let totalAttendance = near.reduce(0) { $0 + $1.expectedAttendance }
        let score: Int = {
            if highImpact >= 2 || totalAttendance > 50_000 { return 90 }
            if highImpact >= 1 || totalAttendance > 15_000 { return 78 }
            if near.count >= 3 { return 65 }
            return 55
        }()
        let topName = near.first?.title ?? ""
        let details = "\(near.count) events in next 14 days. Top: \(topName). Est. \(totalAttendance.formatted()) attendees."

        if let idx = demandSignals.firstIndex(where: { $0.source == .localEvents }) {
            demandSignals[idx] = DemandSignal(id: demandSignals[idx].id, date: .now, source: .localEvents, score: score, details: details)
        } else {
            demandSignals.append(DemandSignal(source: .localEvents, score: score, details: details))
        }
    }

    func refreshRates() async {
        isRefreshingRates = true

        if competitors.contains(where: { $0.xoteloKey.isEmpty }) {
            let resolved = await rateService.resolveXoteloKeys(for: competitors)
            competitors = resolved
        }

        let updatedCompetitors = await rateService.fetchCompetitorRates(competitors: competitors)
        competitors = updatedCompetitors

        if hotel.xoteloKey.isEmpty {
            let hotelKey = await rateService.resolveHotelXoteloKey(hotel: hotel)
            if !hotelKey.isEmpty {
                hotel.xoteloKey = hotelKey
            }
        }

        if !hotel.xoteloKey.isEmpty {
            let updatedHotelRates = await rateService.fetchHotelOTARates(hotel: hotel)
            for updated in updatedHotelRates {
                if let index = hotelRates.firstIndex(where: { $0.roomTypeId == updated.roomTypeId }) {
                    hotelRates[index].otaRates = updated.otaRates
                    if updated.currentRate > 0 {
                        hotelRates[index].currentRate = updated.currentRate
                        hotelRates[index].source = updated.source
                    }
                    hotelRates[index].lastUpdated = .now
                }
            }
        }

        updateDemandSignalsFromCompetitors()

        lastRateRefresh = .now
        isRefreshingRates = false
        persistData()
    }

    func completeSetup(
        hotel: Hotel,
        roomTypes: [RoomType],
        competitors: [Competitor],
        demandSignals: [DemandSignal]
    ) {
        clearPersistedData()

        self.hotel = hotel
        self.competitors = competitors
        self.demandSignals = demandSignals
        self.recommendations = []
        self.alerts = []

        let activeRoomTypes = roomTypes.filter { !$0.name.isEmpty }
        self.hotelRates = activeRoomTypes.map { rt in
            HotelRateEntry(
                roomTypeId: rt.id, roomTypeName: rt.name,
                currentRate: rt.baseRate, source: .manual,
                otaRates: []
            )
        }
        self.occupancyEntries = activeRoomTypes.map { rt in
            OccupancyEntry(
                roomTypeId: rt.id, roomTypeName: rt.name,
                date: .now, roomsSold: 0, totalRooms: rt.count
            )
        }

        persistData()

        Task {
            await resolveCompetitorKeysAndRefresh()
            regenerateRecommendations()
            persistData()
            await refreshLocalEvents()
        }
    }

    func signOut() {
        HotelRegistrationService.shared.unregisterHotel(
            name: hotel.name,
            latitude: hotel.latitude,
            longitude: hotel.longitude
        )
        hasCompletedOnboarding = false
        hasCompletedSetup = false
        hotel = Hotel()
        competitors = []
        demandSignals = []
        recommendations = []
        alerts = []
        localEvents = []
        lastEventsRefresh = nil
        eventsErrorMessage = nil
        occupancyEntries = []
        hotelRates = []
        currentTier = .scout
        isRefreshingRates = false
        lastRateRefresh = .now
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "hasCompletedOnboarding")
        defaults.set(false, forKey: "hasCompletedSetup")
        clearPersistedData()
    }

    func regenerateRecommendations() {
        let newRecs = rateService.generateDynamicRecommendations(
            hotelRates: hotelRates,
            competitors: competitors,
            occupancy: occupancyEntries,
            demandScore: demandScore,
            strategy: hotel.pricingStrategy,
            riskTolerance: hotel.riskTolerance,
            maxAdjustment: hotel.maxRateAdjustment,
            roomTypes: hotel.roomTypes
        )
        if !newRecs.isEmpty {
            recommendations = newRecs
        }
    }

    private func updateDemandSignalsFromCompetitors() {
        let activeCompetitors = competitors.filter { $0.currentRate > 0 }
        guard !activeCompetitors.isEmpty else { return }

        let avgCompRate = activeCompetitors.map(\.currentRate).reduce(0, +) / Double(activeCompetitors.count)
        let soldOutCount = competitors.filter { $0.availability == "Sold Out" }.count
        let noDataCount = competitors.filter { $0.xoteloKey.isEmpty || $0.currentRate == 0 }.count

        var updatedSignals: [DemandSignal] = []

        let competitorScore: Int = {
            if soldOutCount > 2 { return 85 }
            if soldOutCount > 0 { return 70 }
            let rateSpread = activeCompetitors.map(\.currentRate).max().map { $0 - (activeCompetitors.map(\.currentRate).min() ?? 0) } ?? 0
            if rateSpread > avgCompRate * 0.3 { return 60 }
            return 50
        }()
        updatedSignals.append(DemandSignal(
            source: .competitorAvailability,
            score: competitorScore,
            details: "\(activeCompetitors.count) competitors tracked, avg \(avgCompRate.formatted(.currency(code: "USD").precision(.fractionLength(0)))). \(soldOutCount) sold out."
        ))

        if let existingSeason = demandSignals.first(where: { $0.source == .seasonality }) {
            updatedSignals.append(existingSeason)
        } else {
            updatedSignals.append(DemandSignal(source: .seasonality, score: 55, details: "Baseline seasonality for your area."))
        }

        if let existingWeather = demandSignals.first(where: { $0.source == .weather }) {
            updatedSignals.append(existingWeather)
        } else {
            updatedSignals.append(DemandSignal(source: .weather, score: 45, details: "Weather conditions being tracked."))
        }

        demandSignals = updatedSignals
    }
}
