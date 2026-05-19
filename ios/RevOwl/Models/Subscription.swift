import Foundation

nonisolated enum SubscriptionTier: String, Codable, Sendable, CaseIterable, Identifiable {
    case scout = "Scout"
    case growth = "Growth"
    case pro = "Pro"
    var id: String { rawValue }

    var displayName: String { rawValue }

    var price: String {
        switch self {
        case .scout: return "Free"
        case .growth: return "$9.99/mo"
        case .pro: return "$29.99/mo"
        }
    }

    var competitorLimit: Int {
        switch self {
        case .scout: return 1
        case .growth: return 3
        case .pro: return 5
        }
    }

    var refreshInterval: String {
        switch self {
        case .scout: return "6hr"
        case .growth: return "2hr"
        case .pro: return "2x/hr"
        }
    }

    var historyDays: Int {
        switch self {
        case .scout: return 7
        case .growth: return 30
        case .pro: return 90
        }
    }
}

nonisolated struct OccupancyEntry: Codable, Sendable, Identifiable {
    let id: String
    var roomTypeId: String
    var roomTypeName: String
    var date: Date
    var roomsSold: Int
    var totalRooms: Int
    var source: String

    var occupancyRate: Double {
        guard totalRooms > 0 else { return 0 }
        return Double(roomsSold) / Double(totalRooms)
    }

    init(
        id: String = UUID().uuidString, roomTypeId: String = "", roomTypeName: String = "",
        date: Date = .now, roomsSold: Int = 0, totalRooms: Int = 0, source: String = "Manual"
    ) {
        self.id = id; self.roomTypeId = roomTypeId; self.roomTypeName = roomTypeName
        self.date = date; self.roomsSold = roomsSold; self.totalRooms = totalRooms; self.source = source
    }
}
