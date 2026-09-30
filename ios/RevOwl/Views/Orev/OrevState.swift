import Foundation

/// Orev's expressive states. Every state has a text description for VoiceOver, and
/// essential information is always also shown as text next to Orev.
enum OrevState: String, CaseIterable, Sendable {
    case welcome, idle, listening, thinking, explaining, opportunity, uncertainty, celebrating, errorRecovery

    /// Maps a backend mood string to a state.
    init(mood: String) {
        switch mood {
        case "opportunity": self = .opportunity
        case "uncertainty": self = .uncertainty
        case "celebrating": self = .celebrating
        case "explaining": self = .explaining
        default: self = .idle
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .welcome: "Waving hello"
        case .idle: "Resting"
        case .listening: "Listening"
        case .thinking: "Thinking"
        case .explaining: "Explaining"
        case .opportunity: "Spotted an opportunity"
        case .uncertainty: "Unsure, some data is missing"
        case .celebrating: "Celebrating"
        case .errorRecovery: "Recovering from a problem"
        }
    }

    var statusText: String {
        switch self {
        case .welcome: "Hello!"
        case .idle: "Ready when you are"
        case .listening: "Listening…"
        case .thinking: "Checking your data…"
        case .explaining: "Here's what I found"
        case .opportunity: "I spotted something"
        case .uncertainty: "Some data is missing"
        case .celebrating: "Nice work!"
        case .errorRecovery: "Let's try that again"
        }
    }
}
