import Foundation

nonisolated enum DemandSource: String, Codable, Sendable, CaseIterable {
    case airport = "Airport Arrivals"
    case cruisePort = "Cruise Port"
    case localEvents = "Local Events"
    case traffic = "Traffic"
    case competitorAvailability = "Competitor Availability"
    case weather = "Weather"
    case seasonality = "Seasonality"

    var icon: String {
        switch self {
        case .airport: return "airplane.arrival"
        case .cruisePort: return "ferry.fill"
        case .localEvents: return "ticket.fill"
        case .traffic: return "car.fill"
        case .competitorAvailability: return "building.2.fill"
        case .weather: return "cloud.sun.fill"
        case .seasonality: return "calendar"
        }
    }
}

nonisolated struct DemandSignal: Codable, Sendable, Identifiable {
    let id: String
    var date: Date
    var source: DemandSource
    var score: Int
    var details: String

    init(id: String = UUID().uuidString, date: Date = .now, source: DemandSource = .seasonality, score: Int = 50, details: String = "") {
        self.id = id; self.date = date; self.source = source; self.score = score; self.details = details
    }
}
