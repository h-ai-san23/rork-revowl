import Foundation

nonisolated struct FieldSource: Codable, Sendable, Hashable {
    let source: String
    let confidence: String?
    let url: String?
    let confirmedAt: Double?
}

nonisolated struct Profile: Codable, Sendable, Hashable {
    let id: String
    let name: String
    let address: String?
    let city: String?
    let region: String?
    let country: String?
    let countryCode: String?
    let latitude: Double?
    let longitude: Double?
    let timeZone: String
    let currency: String
    let roomCount: Int?
    let website: String?
    let phone: String?
    let starRating: Double?
    let propertyType: String?
    let amenities: [String]
    let description: String?
    let goals: [String]
    let xoteloKey: String?
    let xoteloName: String?
    let setupStep: String
    let setupCompleted: Bool
    let fieldSources: [String: FieldSource]
    let createdAt: Double
    let updatedAt: Double
}

nonisolated struct PlanLimits: Codable, Sendable, Hashable {
    let competitors: Int
    let teamMembers: Int
    let orevAnswersPerMonth: Int
    let orevAnswersPerTrial: Int
    let eventHorizonDays: Int
    let rateRefreshesPerDay: Int
    let rateHorizonDays: Int
    let monthlyCostCeilingUsd: Double
}

nonisolated struct PlanInfo: Codable, Sendable, Hashable {
    /// Effective plan used for limits ("none" when expired).
    let id: String
    /// Plan the property purchased most recently, even if expired.
    let purchasedPlan: String
    let state: String
    let expiresAt: Double?
    let willRenew: Bool
    let trialUsed: Bool
    let billingIssue: Bool
    let managementUrl: String?
    let verifiedAt: Double?
    let trialDays: Int
    let limits: PlanLimits

    var isPaid: Bool { state == "trial" || state == "active" || state == "grace" }
}

nonisolated struct UsageInfo: Codable, Sendable, Hashable {
    let month: String
    let orevAnswersUsed: Int
    let orevAnswersAllowed: Int
    let budgetReached: Bool
}

nonisolated struct PropertyCounts: Codable, Sendable, Hashable {
    let competitors: Int
    let activeCompetitors: Int
    let members: Int
    let performanceDays: Int
    let sampleDays: Int
}

nonisolated struct NeedsAttention: Codable, Sendable, Hashable {
    let competitorsOverLimit: Bool
    let membersOverLimit: Bool
}

nonisolated struct PropertyOverview: Codable, Sendable {
    var profile: Profile
    let role: String
    let plan: PlanInfo
    let usage: UsageInfo
    let counts: PropertyCounts
    let needsAttention: NeedsAttention
    let today: String
}

nonisolated struct PublicPlan: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let priceUsdMonthly: Double
    let productId: String?
    let entitlement: String?
    let recommended: Bool
    let tagline: String
    let limits: PlanLimits
    let features: [String]
}

nonisolated struct PlansResponse: Codable, Sendable {
    let trialDays: Int
    let currency: String
    let billingPeriod: String
    let plans: [PublicPlan]
}

nonisolated struct SetupStepResponse: Codable, Sendable {
    let setupStep: String
    let setupCompleted: Bool
}

nonisolated struct ListingResponse: Codable, Sendable {
    let xoteloKey: String?
    let xoteloName: String?
}

nonisolated struct Competitor: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let xoteloKey: String?
    let latitude: Double?
    let longitude: Double?
    let distanceKm: Double?
    let rating: Double?
    let priority: Int
    let active: Bool
    let addedAt: Double
}

nonisolated struct CompetitorsResponse: Codable, Sendable {
    let competitors: [Competitor]
    let limit: Int
}

nonisolated struct HotelCandidate: Codable, Sendable, Hashable, Identifiable {
    let key: String
    let name: String
    let url: String?
    let latitude: Double?
    let longitude: Double?
    let distanceKm: Double?
    let rating: Double?
    let reviewCount: Int?
    let priceMin: Double?
    let priceMax: Double?
    let matchScore: Double
    var id: String { key }
}

nonisolated struct MatchResult: Codable, Sendable {
    let candidates: [HotelCandidate]
    let locationKey: String?
    let nearby: [HotelCandidate]
    let cachedAt: Double?
}

nonisolated struct PerformanceRow: Codable, Sendable, Hashable {
    let date: String
    let kind: String
    let roomsAvailable: Int
    let roomsSold: Int
    let roomRevenue: Double?
    let source: String
    let capturedAt: Double

    var occupancy: Double? { roomsAvailable > 0 ? Double(roomsSold) / Double(roomsAvailable) : nil }
}

nonisolated struct PerformanceResponse: Codable, Sendable {
    let rows: [PerformanceRow]
    let snapshots: Int
    let today: String
}

nonisolated struct ImportIssue: Codable, Sendable, Hashable {
    let row: Int
    let field: String
    let message: String
}

nonisolated struct DateSpan: Codable, Sendable, Hashable {
    let start: String
    let end: String
}

nonisolated struct CsvPreview: Codable, Sendable {
    let totalLines: Int
    let validRows: Int
    let issues: [ImportIssue]
    let issueCount: Int
    let range: DateSpan?
    let actualDays: Int
    let onTheBooksDays: Int
    let committed: Bool
}

nonisolated struct WriteResult: Codable, Sendable {
    let accepted: Int
    let issues: [ImportIssue]
}

nonisolated struct TeamMember: Codable, Sendable, Hashable, Identifiable {
    let accountId: String
    let role: String
    let name: String?
    let email: String?
    let addedAt: Double
    let active: Bool
    var id: String { accountId }
}

nonisolated struct TeamResponse: Codable, Sendable {
    let members: [TeamMember]
    let limit: Int
}

nonisolated struct InviteResponse: Codable, Sendable {
    let code: String
    let role: String
    let expiresInDays: Int
}

nonisolated struct ExtractedString: Codable, Sendable, Hashable {
    let value: String
    let confidence: String
    let evidence: String?
    let source: String
}

nonisolated struct ExtractedNumber: Codable, Sendable, Hashable {
    let value: Double
    let confidence: String
    let evidence: String?
    let source: String
}

nonisolated struct ExtractedList: Codable, Sendable, Hashable {
    let value: [String]
    let confidence: String
    let evidence: String?
    let source: String
}

nonisolated struct ExtractionFields: Codable, Sendable, Hashable {
    let name: ExtractedString?
    let address: ExtractedString?
    let city: ExtractedString?
    let country: ExtractedString?
    let phone: ExtractedString?
    let email: ExtractedString?
    let starRating: ExtractedNumber?
    let roomCount: ExtractedNumber?
    let checkInTime: ExtractedString?
    let checkOutTime: ExtractedString?
    let propertyType: ExtractedString?
    let amenities: ExtractedList?
    let description: ExtractedString?
}

nonisolated struct WebsiteExtraction: Codable, Sendable, Hashable {
    let sourceUrl: String
    let fetchedAt: Double
    let fields: ExtractionFields
    let notInferred: [String]
    let warnings: [String]
}
