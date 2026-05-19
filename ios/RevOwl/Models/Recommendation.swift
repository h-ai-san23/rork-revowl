import Foundation

nonisolated enum ConfidenceLevel: String, Codable, Sendable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var color: String {
        switch self {
        case .high: return "green"
        case .medium: return "orange"
        case .low: return "red"
        }
    }
}

nonisolated enum RecommendationStatus: String, Codable, Sendable {
    case pending = "Pending"
    case applied = "Applied"
    case dismissed = "Dismissed"
    case snoozed = "Snoozed"
}

nonisolated struct Recommendation: Codable, Sendable, Identifiable {
    let id: String
    var roomTypeId: String
    var roomTypeName: String
    var currentRate: Double
    var recommendedRate: Double
    var confidence: ConfidenceLevel
    var reasoning: String
    var status: RecommendationStatus
    var expectedADRImpact: Double
    var expectedOccupancyImpact: Double
    var dateRange: String
    var createdAt: Date

    var percentChange: Double {
        guard currentRate > 0 else { return 0 }
        return ((recommendedRate - currentRate) / currentRate) * 100
    }

    init(
        id: String = UUID().uuidString, roomTypeId: String = "", roomTypeName: String = "",
        currentRate: Double = 0, recommendedRate: Double = 0, confidence: ConfidenceLevel = .medium,
        reasoning: String = "", status: RecommendationStatus = .pending,
        expectedADRImpact: Double = 0, expectedOccupancyImpact: Double = 0,
        dateRange: String = "", createdAt: Date = .now
    ) {
        self.id = id; self.roomTypeId = roomTypeId; self.roomTypeName = roomTypeName
        self.currentRate = currentRate; self.recommendedRate = recommendedRate
        self.confidence = confidence; self.reasoning = reasoning; self.status = status
        self.expectedADRImpact = expectedADRImpact; self.expectedOccupancyImpact = expectedOccupancyImpact
        self.dateRange = dateRange; self.createdAt = createdAt
    }
}
