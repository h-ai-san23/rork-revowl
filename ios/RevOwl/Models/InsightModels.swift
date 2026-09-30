import Foundation

nonisolated struct MarketDay: Codable, Sendable, Hashable, Identifiable {
    let stayDate: String
    let ownLowest: Double?
    let compLowest: Double?
    let compMedian: Double?
    let compHighest: Double?
    let compCount: Int
    let positionVsMedian: Double?
    let rank: Int?
    let observedAt: Double?
    var id: String { stayDate }
}

nonisolated struct RateCell: Codable, Sendable, Hashable {
    let rate: Double
    let channel: String
    let observedAt: Double
    let manual: Bool
}

nonisolated struct MarketCompetitor: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let hasData: Bool
    let active: Bool
}

nonisolated struct RefreshInfo: Codable, Sendable, Hashable {
    let perDay: Int
    let usedToday: Int
    let remainingToday: Int
    let inProgress: Bool
    let pending: Int
    let started: Bool?
    let total: Int?
}

nonisolated struct MarketResponse: Codable, Sendable {
    let provider: String
    let providerStatus: String
    let currency: String
    let lastRefreshAt: Double?
    let ownTracked: Bool
    let competitors: [MarketCompetitor]
    let days: [MarketDay]
    let byHotel: [String: [String: RateCell]]
    let horizonDays: Int
    let refresh: RefreshInfo
}

nonisolated struct EventRow: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let title: String
    let startDate: String
    let endDate: String
    let venue: String?
    let category: String
    let sourceUrl: String?
    let sourceTitle: String?
    let expectedAttendance: Int?
    let sourceReachable: Bool
    let status: String
    let origin: String
    let createdAt: Double

    func covers(_ iso: String) -> Bool { iso >= startDate && iso <= endDate }
}

nonisolated struct EventsResponse: Codable, Sendable {
    let events: [EventRow]
    let horizonDays: Int
    let lastDiscoveryAt: Double?
}

nonisolated struct DiscoverResult: Codable, Sendable {
    let added: Int
    let found: Int?
    let skipped: Bool
    let message: String?
    let lastDiscoveryAt: Double?
}

nonisolated struct HeadlineMetric: Codable, Sendable, Hashable, Identifiable {
    let key: String
    let label: String
    let value: Double?
    let formatted: String
    let basis: String
    let period: String
    let note: String?
    var id: String { key }
}

nonisolated struct EvidenceItem: Codable, Sendable, Hashable {
    let label: String
    let value: String
    let basis: String
    let source: String
    let asOf: String?
}

nonisolated struct InsightAction: Codable, Sendable, Hashable {
    let label: String
    let target: String
}

nonisolated struct Insight: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let kind: String
    let title: String
    let detail: String
    let evidence: [EvidenceItem]
    let labels: [String]
    let action: InsightAction?
    let date: String?
}

nonisolated struct Briefing: Codable, Sendable {
    let date: String
    let generatedAt: Double
    let greeting: String
    let summary: String
    let summarySource: String
    let mood: String
    let headline: [HeadlineMetric]
    let insights: [Insight]
    let dataGaps: [String]
    let hasSampleData: Bool
}

nonisolated struct AskEvidence: Codable, Sendable, Hashable {
    let tool: String
    let summary: String
    let basis: String
}

nonisolated struct AskUsage: Codable, Sendable, Hashable {
    let used: Int
    let allowed: Int
}

nonisolated struct AskResponse: Codable, Sendable {
    let id: String
    let answer: String
    let mood: String
    let evidence: [AskEvidence]
    let followUps: [String]
    let usage: AskUsage
}

nonisolated struct AskHistoryItem: Codable, Sendable, Identifiable {
    let id: String
    let question: String
    let answer: String
    let mood: String
    let evidence: [AskEvidence]
    let followUps: [String]
    let createdAt: Double
}

nonisolated struct AskHistoryResponse: Codable, Sendable {
    let items: [AskHistoryItem]
}

nonisolated struct AskTurn: Codable, Sendable {
    let role: String
    let text: String
}
