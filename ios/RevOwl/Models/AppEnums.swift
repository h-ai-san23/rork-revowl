import Foundation

enum AppTab: Hashable {
    case today, market, calendar, ask, property
}

/// Onboarding steps. Steps from `website` onward are persisted on the server so setup resumes.
enum OnboardingStep: String, CaseIterable, Hashable {
    case welcome
    case signIn
    case property
    case website
    case confirm
    case rooms
    case locale
    case dataImport = "import"
    case competitors
    case goals
    case overview
    case plans
    case briefing

    var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    var isServerStep: Bool { index >= OnboardingStep.website.index }

    var next: OnboardingStep? {
        let all = Self.allCases
        return index + 1 < all.count ? all[index + 1] : nil
    }

    var previous: OnboardingStep? {
        guard isServerStep, self != .website else { return nil }
        return Self.allCases[index - 1]
    }

    var shortTitle: String {
        switch self {
        case .welcome: "Welcome"
        case .signIn: "Account"
        case .property: "Property"
        case .website: "Website"
        case .confirm: "Details"
        case .rooms: "Rooms"
        case .locale: "Currency & time"
        case .dataImport: "Your data"
        case .competitors: "Competitors"
        case .goals: "Goals"
        case .overview: "Overview"
        case .plans: "Plans"
        case .briefing: "First briefing"
        }
    }
}

struct GoalOption: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String

    static let all: [GoalOption] = [
        GoalOption(id: "grow_revpar", title: "Grow RevPAR", icon: "chart.line.uptrend.xyaxis"),
        GoalOption(id: "fill_midweek", title: "Fill quiet midweek nights", icon: "calendar.badge.plus"),
        GoalOption(id: "raise_adr", title: "Raise my average rate", icon: "arrow.up.right.circle"),
        GoalOption(id: "beat_compset", title: "Keep pace with competitors", icon: "binoculars"),
        GoalOption(id: "reduce_ota", title: "Rely less on OTAs", icon: "arrow.triangle.branch"),
        GoalOption(id: "understand_events", title: "Plan around local events", icon: "ticket"),
        GoalOption(id: "save_time", title: "Spend less time on pricing", icon: "clock"),
    ]
}

enum CurrencyOptions {
    static let common: [String] = ["USD", "EUR", "GBP", "CAD", "AUD", "NZD", "CHF", "JPY", "MXN", "BRL", "AED", "SAR", "SGD", "HKD", "THB", "IDR", "INR", "ZAR", "SEK", "NOK", "DKK", "PLN", "CZK", "TRY", "KRW", "CNY", "PHP", "MYR", "COP", "CLP", "PEN", "ARS", "EGP", "MAD", "ILS", "HUF", "ISK"]

    static func name(_ code: String) -> String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }

    static func forRegion(_ regionCode: String?) -> String? {
        guard let regionCode, !regionCode.isEmpty else { return nil }
        return Locale(identifier: "en_\(regionCode.uppercased())").currency?.identifier
    }
}
