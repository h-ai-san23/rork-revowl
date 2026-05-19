import Foundation

nonisolated enum AlertType: String, Codable, Sendable {
    case rateChange = "Rate Change"
    case demandSurge = "Demand Surge"
    case aiRecommendation = "AI Recommendation"
    case occupancyReminder = "Occupancy Reminder"
    case rateParity = "Rate Parity"
    case weeklySummary = "Weekly Summary"

    var icon: String {
        switch self {
        case .rateChange: return "arrow.up.arrow.down.circle.fill"
        case .demandSurge: return "flame.fill"
        case .aiRecommendation: return "brain.fill"
        case .occupancyReminder: return "bell.badge.fill"
        case .rateParity: return "exclamationmark.triangle.fill"
        case .weeklySummary: return "chart.bar.doc.horizontal.fill"
        }
    }

    var colorName: String {
        switch self {
        case .rateChange: return "blue"
        case .demandSurge: return "red"
        case .aiRecommendation: return "purple"
        case .occupancyReminder: return "orange"
        case .rateParity: return "yellow"
        case .weeklySummary: return "green"
        }
    }
}

nonisolated struct AlertItem: Codable, Sendable, Identifiable {
    let id: String
    var type: AlertType
    var title: String
    var message: String
    var isRead: Bool
    var sentAt: Date

    init(id: String = UUID().uuidString, type: AlertType = .rateChange, title: String = "", message: String = "", isRead: Bool = false, sentAt: Date = .now) {
        self.id = id; self.type = type; self.title = title; self.message = message; self.isRead = isRead; self.sentAt = sentAt
    }
}
