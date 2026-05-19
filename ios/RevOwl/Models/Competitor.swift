import Foundation

nonisolated struct Competitor: Codable, Sendable, Identifiable, Hashable {
    let id: String
    var name: String
    var latitude: Double
    var longitude: Double
    var distance: Double
    var stars: Int
    var otaPresence: [String]
    var isActive: Bool
    var currentRate: Double
    var rateChange: Double
    var availability: String
    var otaRates: [OTARateInfo]
    var lastRateUpdate: Date
    var xoteloKey: String
    var address: String?

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
        id: String = UUID().uuidString, name: String = "", latitude: Double = 0,
        longitude: Double = 0, distance: Double = 0, stars: Int = 3,
        otaPresence: [String] = [], isActive: Bool = true, currentRate: Double = 0,
        rateChange: Double = 0, availability: String = "Available",
        otaRates: [OTARateInfo] = [], lastRateUpdate: Date = .now,
        xoteloKey: String = "", address: String? = nil
    ) {
        self.id = id; self.name = name; self.latitude = latitude; self.longitude = longitude
        self.distance = distance; self.stars = stars; self.otaPresence = otaPresence
        self.isActive = isActive; self.currentRate = currentRate
        self.rateChange = rateChange; self.availability = availability
        self.otaRates = otaRates; self.lastRateUpdate = lastRateUpdate
        self.xoteloKey = xoteloKey; self.address = address
    }
}

nonisolated struct CompetitorRate: Codable, Sendable, Identifiable {
    let id: String
    var competitorId: String
    var roomType: String
    var rate: Double
    var date: Date
    var otaSource: String
    var availability: Bool
    var timestamp: Date
}
