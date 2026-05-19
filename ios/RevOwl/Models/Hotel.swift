import Foundation

nonisolated enum PropertyType: String, Codable, Sendable, CaseIterable, Identifiable {
    case boutique = "Boutique"
    case limitedService = "Limited Service"
    case fullService = "Full Service"
    case resort = "Resort"
    var id: String { rawValue }
}

nonisolated enum PricingStrategy: String, Codable, Sendable, CaseIterable, Identifiable {
    case occupancyFocused = "Occupancy-Focused"
    case adrFocused = "ADR-Focused"
    case balanced = "Balanced"
    var id: String { rawValue }
    var description: String {
        switch self {
        case .occupancyFocused: return "Maximize rooms sold"
        case .adrFocused: return "Maximize average daily rate"
        case .balanced: return "Balance occupancy and rate"
        }
    }
    var icon: String {
        switch self {
        case .occupancyFocused: return "bed.double.fill"
        case .adrFocused: return "dollarsign.circle.fill"
        case .balanced: return "scale.3d"
        }
    }
}

nonisolated struct Hotel: Codable, Sendable, Identifiable {
    let id: String
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var totalRooms: Int
    var roomTypes: [RoomType]
    var starRating: Int
    var propertyType: PropertyType
    var ownerId: String
    var tier: SubscriptionTier
    var pricingStrategy: PricingStrategy
    var riskTolerance: Double
    var maxRateAdjustment: Double
    var xoteloKey: String
    var registrationId: String

    init(
        id: String = UUID().uuidString, name: String = "", address: String = "",
        latitude: Double = 0, longitude: Double = 0, totalRooms: Int = 0,
        roomTypes: [RoomType] = [], starRating: Int = 3,
        propertyType: PropertyType = .boutique, ownerId: String = "",
        tier: SubscriptionTier = .scout, pricingStrategy: PricingStrategy = .balanced,
        riskTolerance: Double = 0.5, maxRateAdjustment: Double = 0.15,
        xoteloKey: String = "", registrationId: String = ""
    ) {
        self.id = id; self.name = name; self.address = address
        self.latitude = latitude; self.longitude = longitude; self.totalRooms = totalRooms
        self.roomTypes = roomTypes; self.starRating = starRating
        self.propertyType = propertyType; self.ownerId = ownerId; self.tier = tier
        self.pricingStrategy = pricingStrategy; self.riskTolerance = riskTolerance
        self.maxRateAdjustment = maxRateAdjustment; self.xoteloKey = xoteloKey
        self.registrationId = registrationId
    }
}

nonisolated struct RoomType: Codable, Sendable, Identifiable, Hashable {
    let id: String
    var name: String
    var baseRate: Double
    var floorRate: Double
    var count: Int
    init(id: String = UUID().uuidString, name: String = "", baseRate: Double = 0, floorRate: Double = 0, count: Int = 0) {
        self.id = id; self.name = name; self.baseRate = baseRate; self.floorRate = floorRate; self.count = count
    }
}
