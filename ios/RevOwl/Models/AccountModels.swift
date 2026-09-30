import Foundation

nonisolated struct AccountProperty: Codable, Sendable, Hashable, Identifiable {
    let propertyId: String
    let role: String
    let name: String
    let addedAt: Double?
    var id: String { propertyId }
}

nonisolated struct AccountMe: Codable, Sendable {
    let id: String
    let email: String?
    let name: String?
    let createdAt: Double?
    let properties: [AccountProperty]
}

nonisolated struct AuthResponse: Codable, Sendable {
    let token: String
    let expiresAt: Double
    let isNewAccount: Bool
    let account: AccountMe
}

nonisolated struct HealthCapabilities: Codable, Sendable {
    let ai: Bool
    let billingVerification: Bool
    let billingWebhook: Bool
    let deviceSignIn: Bool
}

nonisolated struct HealthResponse: Codable, Sendable {
    let ok: Bool
    let capabilities: HealthCapabilities?
}

nonisolated struct OKResponse: Codable, Sendable {
    let ok: Bool?
}

nonisolated struct InviteAcceptResponse: Codable, Sendable {
    let propertyId: String
    let alreadyMember: Bool
}
