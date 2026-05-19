import Foundation

nonisolated enum RateSource: String, Codable, Sendable, CaseIterable, Identifiable {
    case manual = "Manual"
    case bookingCom = "Booking.com"
    case expedia = "Expedia"
    case hotelsCom = "Hotels.com"
    case agoda = "Agoda"
    case priceline = "Priceline"
    case googleHotels = "Google Hotels"
    case tripCom = "Trip.com"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .manual: return "hand.raised.fill"
        case .bookingCom: return "b.circle.fill"
        case .expedia: return "e.circle.fill"
        case .hotelsCom: return "h.circle.fill"
        case .agoda: return "a.circle.fill"
        case .priceline: return "p.circle.fill"
        case .googleHotels: return "g.circle.fill"
        case .tripCom: return "t.circle.fill"
        }
    }

    var brandColor: String {
        switch self {
        case .manual: return "gray"
        case .bookingCom: return "blue"
        case .expedia: return "yellow"
        case .hotelsCom: return "red"
        case .agoda: return "pink"
        case .priceline: return "blue"
        case .googleHotels: return "green"
        case .tripCom: return "cyan"
        }
    }
}

nonisolated enum RateDisplayMode: String, Codable, Sendable {
    case perRoomType
    case average
}

nonisolated struct OTARateInfo: Codable, Sendable, Identifiable, Hashable {
    let id: String
    var otaName: String
    var rate: Double
    var tax: Double
    var roomType: String
    var lastUpdated: Date

    init(id: String = UUID().uuidString, otaName: String, rate: Double, tax: Double = 0, roomType: String = "Standard", lastUpdated: Date = .now) {
        self.id = id; self.otaName = otaName; self.rate = rate; self.tax = tax; self.roomType = roomType; self.lastUpdated = lastUpdated
    }

    var totalWithTax: Double { rate + tax }
}

nonisolated struct HotelRateEntry: Codable, Sendable, Identifiable {
    let id: String
    var roomTypeId: String
    var roomTypeName: String
    var currentRate: Double
    var source: RateSource
    var lastUpdated: Date
    var otaRates: [OTARateInfo]

    var averageOTARate: Double {
        guard !otaRates.isEmpty else { return currentRate }
        return otaRates.map(\.rate).reduce(0, +) / Double(otaRates.count)
    }

    var lowestOTARate: Double {
        otaRates.map(\.rate).min() ?? currentRate
    }

    var highestOTARate: Double {
        otaRates.map(\.rate).max() ?? currentRate
    }

    init(
        id: String = UUID().uuidString, roomTypeId: String, roomTypeName: String,
        currentRate: Double, source: RateSource = .manual, lastUpdated: Date = .now,
        otaRates: [OTARateInfo] = []
    ) {
        self.id = id; self.roomTypeId = roomTypeId; self.roomTypeName = roomTypeName
        self.currentRate = currentRate; self.source = source; self.lastUpdated = lastUpdated
        self.otaRates = otaRates
    }
}
