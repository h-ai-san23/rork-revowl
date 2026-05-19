import Foundation

enum MockData {
    static let hotel = Hotel(
        id: "hotel-1", name: "The Coastal Inn", address: "123 Ocean Drive, Miami Beach, FL",
        latitude: 25.7617, longitude: -80.1918, totalRooms: 86,
        roomTypes: roomTypes, starRating: 4, propertyType: .boutique,
        ownerId: "owner-1", tier: .pro, pricingStrategy: .balanced,
        riskTolerance: 0.5, maxRateAdjustment: 0.15,
        xoteloKey: "g34439-d286664"
    )

    static let roomTypes: [RoomType] = [
        RoomType(id: "rt-1", name: "King", baseRate: 169, floorRate: 129, count: 30),
        RoomType(id: "rt-2", name: "Double Queen", baseRate: 149, floorRate: 109, count: 35),
        RoomType(id: "rt-3", name: "Suite", baseRate: 259, floorRate: 199, count: 12),
        RoomType(id: "rt-4", name: "Standard", baseRate: 119, floorRate: 89, count: 9),
    ]

    static let hotelRates: [HotelRateEntry] = [
        HotelRateEntry(roomTypeId: "rt-1", roomTypeName: "King", currentRate: 169, source: .bookingCom, otaRates: [
            OTARateInfo(otaName: "Booking.com", rate: 169, tax: 35, roomType: "King"),
            OTARateInfo(otaName: "Trip.com", rate: 165, tax: 34, roomType: "King"),
            OTARateInfo(otaName: "Agoda.com", rate: 172, tax: 36, roomType: "King"),
        ]),
        HotelRateEntry(roomTypeId: "rt-2", roomTypeName: "Double Queen", currentRate: 149, source: .bookingCom, otaRates: [
            OTARateInfo(otaName: "Booking.com", rate: 152, tax: 32, roomType: "Double Queen"),
            OTARateInfo(otaName: "Trip.com", rate: 149, tax: 31, roomType: "Double Queen"),
            OTARateInfo(otaName: "Agoda.com", rate: 148, tax: 31, roomType: "Double Queen"),
        ]),
        HotelRateEntry(roomTypeId: "rt-3", roomTypeName: "Suite", currentRate: 259, source: .bookingCom, otaRates: [
            OTARateInfo(otaName: "Booking.com", rate: 259, tax: 54, roomType: "Suite"),
            OTARateInfo(otaName: "Trip.com", rate: 255, tax: 53, roomType: "Suite"),
            OTARateInfo(otaName: "Agoda.com", rate: 262, tax: 55, roomType: "Suite"),
        ]),
        HotelRateEntry(roomTypeId: "rt-4", roomTypeName: "Standard", currentRate: 119, source: .bookingCom, otaRates: [
            OTARateInfo(otaName: "Booking.com", rate: 119, tax: 25, roomType: "Standard"),
            OTARateInfo(otaName: "Trip.com", rate: 115, tax: 24, roomType: "Standard"),
            OTARateInfo(otaName: "Agoda.com", rate: 122, tax: 25, roomType: "Standard"),
        ]),
    ]

    static let competitors: [Competitor] = [
        Competitor(id: "c-1", name: "Hilton Cabana Miami Beach", latitude: 25.8545, longitude: -80.1203, distance: 0.3, stars: 4, otaPresence: ["Booking.com", "Trip.com", "Agoda.com", "Vio.com"], currentRate: 494, rateChange: 0, availability: "Available", otaRates: [
            OTARateInfo(otaName: "Booking.com", rate: 494, tax: 104, roomType: "Standard"),
            OTARateInfo(otaName: "Trip.com", rate: 498, tax: 104, roomType: "Standard"),
            OTARateInfo(otaName: "Agoda.com", rate: 494, tax: 104, roomType: "Standard"),
            OTARateInfo(otaName: "Vio.com", rate: 498, tax: 104, roomType: "Standard"),
        ], xoteloKey: "g34439-d4928161"),
        Competitor(id: "c-2", name: "The Palms Hotel & Spa", latitude: 25.8466, longitude: -80.1209, distance: 0.5, stars: 4, otaPresence: ["Booking.com", "Trip.com", "Agoda.com"], currentRate: 80, rateChange: 0, availability: "Available", otaRates: [
            OTARateInfo(otaName: "Booking.com", rate: 80, tax: 17, roomType: "Standard"),
            OTARateInfo(otaName: "Trip.com", rate: 77, tax: 15, roomType: "Standard"),
            OTARateInfo(otaName: "Agoda.com", rate: 86, tax: 17, roomType: "Standard"),
        ], xoteloKey: "g34439-d286664"),
        Competitor(id: "c-3", name: "Holiday Inn Miami Beach", latitude: 25.759, longitude: -80.195, distance: 0.8, stars: 3, otaPresence: ["Booking.com", "B&B Hotels", "Trip.com", "Vio.com", "Agoda.com"], currentRate: 74, rateChange: 0, availability: "Available", otaRates: [
            OTARateInfo(otaName: "Booking.com", rate: 74, tax: 8, roomType: "Standard"),
            OTARateInfo(otaName: "B&B Hotels", rate: 63, tax: 7, roomType: "Standard"),
            OTARateInfo(otaName: "Trip.com", rate: 58, tax: 7, roomType: "Standard"),
            OTARateInfo(otaName: "Vio.com", rate: 61, tax: 7, roomType: "Standard"),
            OTARateInfo(otaName: "Agoda.com", rate: 59, tax: 7, roomType: "Standard"),
        ], xoteloKey: "g34439-d280967"),
        Competitor(id: "c-4", name: "Hyatt Place Miami Beach", latitude: 25.770, longitude: -80.188, distance: 1.2, stars: 4, otaPresence: ["Booking.com", "Expedia"], currentRate: 189, rateChange: 6.5, availability: "Sold Out", otaRates: [
            OTARateInfo(otaName: "Booking.com", rate: 189, tax: 40, roomType: "Standard"),
            OTARateInfo(otaName: "Expedia", rate: 185, tax: 39, roomType: "Standard"),
        ]),
        Competitor(id: "c-5", name: "Best Western Plus Miami Beach", latitude: 25.755, longitude: -80.200, distance: 1.5, stars: 3, otaPresence: ["Booking.com", "Priceline"], currentRate: 129, rateChange: -1.2, availability: "Available", otaRates: [
            OTARateInfo(otaName: "Booking.com", rate: 129, tax: 27, roomType: "Standard"),
            OTARateInfo(otaName: "Priceline", rate: 125, tax: 26, roomType: "Standard"),
        ]),
    ]

    static let demandSignals: [DemandSignal] = [
        DemandSignal(id: "ds-1", date: .now, source: .airport, score: 78, details: "Airport arrivals +40% vs. last week. 3 delayed flights rerouted."),
        DemandSignal(id: "ds-2", date: .now, source: .localEvents, score: 85, details: "Art Basel Miami — 80,000+ expected attendees. Hotels within 5mi at 92% occupancy."),
        DemandSignal(id: "ds-3", date: .now, source: .competitorAvailability, score: 72, details: "Hyatt Place sold out. Marriott at limited availability."),
        DemandSignal(id: "ds-4", date: .now, source: .weather, score: 30, details: "Clear skies, 78°F. No weather disruptions expected."),
        DemandSignal(id: "ds-5", date: .now, source: .seasonality, score: 65, details: "High season pattern. Historically 15% above average demand."),
    ]

    static let recommendations: [Recommendation] = [
        Recommendation(id: "r-1", roomTypeId: "rt-1", roomTypeName: "King", currentRate: 169, recommendedRate: 179, confidence: .high, reasoning: "3 competitors raised rates. Airport arrivals +40%. Art Basel driving 85 demand score. 22 King rooms unsold.", status: .pending, expectedADRImpact: 12, expectedOccupancyImpact: -2, dateRange: "Dynamic Rate", createdAt: .now),
        Recommendation(id: "r-2", roomTypeId: "rt-2", roomTypeName: "Double Queen", currentRate: 149, recommendedRate: 159, confidence: .high, reasoning: "Competitor avg $155. Hyatt sold out creating compression. Event demand pushing bookings.", status: .pending, expectedADRImpact: 10, expectedOccupancyImpact: -1, dateRange: "Dynamic Rate", createdAt: .now),
        Recommendation(id: "r-3", roomTypeId: "rt-3", roomTypeName: "Suite", currentRate: 259, recommendedRate: 289, confidence: .medium, reasoning: "Suite inventory low (3 left). Premium segment shows price elasticity. Art Basel VIP demand.", status: .pending, expectedADRImpact: 30, expectedOccupancyImpact: -5, dateRange: "Dynamic Rate", createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: .now) ?? .now),
        Recommendation(id: "r-4", roomTypeId: "rt-4", roomTypeName: "Standard", currentRate: 119, recommendedRate: 109, confidence: .low, reasoning: "Standard rooms at 40% occupancy. Consider rate reduction to drive volume. Budget segment price-sensitive.", status: .pending, expectedADRImpact: -10, expectedOccupancyImpact: 8, dateRange: "Dynamic Rate", createdAt: Calendar.current.date(byAdding: .hour, value: -5, to: .now) ?? .now),
    ]

    static let alerts: [AlertItem] = [
        AlertItem(id: "a-1", type: .rateChange, title: "Hilton Cabana Raised to $494", message: "Hilton Cabana Miami Beach rate at $494 on Booking.com. This is significantly above your current rate.", isRead: false, sentAt: .now),
        AlertItem(id: "a-2", type: .demandSurge, title: "Demand Score 85", message: "Airport arrivals +40%. Art Basel driving surge. 2 competitors at limited availability or sold out.", isRead: false, sentAt: Calendar.current.date(byAdding: .minute, value: -30, to: .now) ?? .now),
        AlertItem(id: "a-3", type: .aiRecommendation, title: "Dynamic Rate: King $179", message: "Based on competitor rates, demand signals, and current occupancy, RevOwl suggests raising King to $179 (+5.9%). Tap to review.", isRead: false, sentAt: Calendar.current.date(byAdding: .hour, value: -1, to: .now) ?? .now),
        AlertItem(id: "a-4", type: .occupancyReminder, title: "Update Today's Occupancy", message: "Update your room counts for accurate dynamic pricing.", isRead: true, sentAt: Calendar.current.date(byAdding: .hour, value: -3, to: .now) ?? .now),
        AlertItem(id: "a-5", type: .rateParity, title: "Rate Parity Warning", message: "King room: Trip.com $165 vs Booking.com $169 vs Agoda.com $172. Discrepancy detected across OTAs.", isRead: true, sentAt: Calendar.current.date(byAdding: .hour, value: -6, to: .now) ?? .now),
        AlertItem(id: "a-6", type: .weeklySummary, title: "Weekly Revenue Summary", message: "ADR +$8 (5.1%). Occupancy 74% (+3%). 6/8 dynamic rates applied. RevPAR $127 (+7.2%).", isRead: true, sentAt: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now),
    ]

    static let occupancyEntries: [OccupancyEntry] = [
        OccupancyEntry(id: "oe-1", roomTypeId: "rt-1", roomTypeName: "King", date: .now, roomsSold: 22, totalRooms: 30),
        OccupancyEntry(id: "oe-2", roomTypeId: "rt-2", roomTypeName: "Double Queen", date: .now, roomsSold: 28, totalRooms: 35),
        OccupancyEntry(id: "oe-3", roomTypeId: "rt-3", roomTypeName: "Suite", date: .now, roomsSold: 9, totalRooms: 12),
        OccupancyEntry(id: "oe-4", roomTypeId: "rt-4", roomTypeName: "Standard", date: .now, roomsSold: 4, totalRooms: 9),
    ]

    static var totalDemandScore: Int {
        let avg = demandSignals.map(\.score).reduce(0, +) / max(demandSignals.count, 1)
        return avg
    }

    static var totalRoomsSold: Int { occupancyEntries.map(\.roomsSold).reduce(0, +) }
    static var totalRoomsAvailable: Int { hotel.totalRooms }
    static var overallOccupancy: Double { Double(totalRoomsSold) / Double(max(totalRoomsAvailable, 1)) }
    static var competitorAvgRate: Double {
        let rates = competitors.map(\.currentRate)
        return rates.reduce(0, +) / Double(max(rates.count, 1))
    }

    static let rateHistory: [(day: String, yours: Double, competitor: Double)] = [
        ("Mon", 159, 162), ("Tue", 162, 165), ("Wed", 165, 168),
        ("Thu", 169, 172), ("Fri", 175, 178), ("Sat", 179, 182), ("Sun", 169, 170)
    ]
}
