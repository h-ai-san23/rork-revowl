import Foundation

nonisolated enum EventCategory: String, Codable, Sendable, CaseIterable {
    case sports = "Sports"
    case concert = "Concert"
    case festival = "Festival"
    case conference = "Conference"
    case performingArts = "Performing Arts"
    case community = "Community"
    case other = "Other"

    var icon: String {
        switch self {
        case .sports: return "sportscourt.fill"
        case .concert: return "music.mic"
        case .festival: return "party.popper.fill"
        case .conference: return "person.3.fill"
        case .performingArts: return "theatermasks.fill"
        case .community: return "figure.2.and.child.holdinghands"
        case .other: return "calendar"
        }
    }
}

nonisolated enum EventImpact: String, Codable, Sendable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

nonisolated struct LocalEvent: Codable, Sendable, Identifiable {
    let id: String
    var title: String
    var venue: String
    var date: Date
    var category: EventCategory
    var expectedAttendance: Int
    var impact: EventImpact
    var distanceMiles: Double
    var sourceURL: String

    init(
        id: String = UUID().uuidString,
        title: String,
        venue: String,
        date: Date,
        category: EventCategory = .other,
        expectedAttendance: Int = 0,
        impact: EventImpact = .medium,
        distanceMiles: Double = 0,
        sourceURL: String = ""
    ) {
        self.id = id; self.title = title; self.venue = venue
        self.date = date; self.category = category
        self.expectedAttendance = expectedAttendance
        self.impact = impact; self.distanceMiles = distanceMiles
        self.sourceURL = sourceURL
    }
}
