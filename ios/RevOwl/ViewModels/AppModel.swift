import Foundation
import Observation
import SwiftUI

/// Root app state: session, the current property, onboarding progress and navigation.
@Observable
@MainActor
final class AppModel {
    enum Route: Equatable { case launching, onboarding, main }

    var route: Route = .launching
    var launchError: String?
    var onboardingStep: OnboardingStep = .welcome
    var me: AccountMe?
    var overview: PropertyOverview?
    var plans: PlansResponse?
    var capabilities: HealthCapabilities?
    var extraction: WebsiteExtraction?
    var selectedTab: AppTab = .today
    /// Bumps whenever property data changes so screens know to reload.
    var dataVersion: Int = 0
    var showPaywall = false
    /// Question handed to Ask Orev from elsewhere (e.g. "Ask Orev why").
    var pendingQuestion: String?

    let api = APIClient.shared
    private let propertyKey = "revowl.currentPropertyId"

    var propertyId: String? { overview?.profile.id }
    var profile: Profile? { overview?.profile }
    var currency: String { overview?.profile.currency ?? "USD" }
    var today: String { overview?.today ?? Fmt.localISO(.now) }
    var canEdit: Bool { overview?.role == "owner" || overview?.role == "manager" }
    var isOwner: Bool { overview?.role == "owner" }
    var plan: PlanInfo? { overview?.plan }

    func path(_ sub: String = "") -> String {
        "/v1/properties/\(propertyId ?? "none")\(sub)"
    }

    func planName(_ id: String) -> String {
        plans?.plans.first { $0.id == id }?.name ?? (id == "none" ? "No plan" : id.capitalized)
    }

    // MARK: Launch

    func bootstrap() async {
        launchError = nil
        async let plansTask: Void = loadPlans()
        async let healthTask: Void = loadHealth()
        if api.token == nil {
            route = .onboarding
            onboardingStep = .welcome
        } else {
            do {
                me = try await api.get("/v1/me")
                await routeAfterSignIn()
            } catch let error as APIError where error.isUnauthenticated {
                Keychain.delete("session_token")
                route = .onboarding
                onboardingStep = .welcome
            } catch {
                launchError = error.userMessage
            }
        }
        _ = await (plansTask, healthTask)
    }

    func loadPlans() async {
        if let result: PlansResponse = try? await api.request("GET", "/v1/plans", authenticated: false) {
            plans = result
        }
    }

    private func loadHealth() async {
        if let health: HealthResponse = try? await api.request("GET", "/v1/health", authenticated: false) {
            capabilities = health.capabilities
        }
    }

    private func routeAfterSignIn() async {
        guard let me else { return }
        let saved = UserDefaults.standard.string(forKey: propertyKey)
        guard let pick = me.properties.first(where: { $0.propertyId == saved }) ?? me.properties.first else {
            overview = nil
            route = .onboarding
            onboardingStep = .property
            return
        }
        do {
            try await selectProperty(pick.propertyId)
        } catch {
            launchError = error.userMessage
            route = .launching
        }
    }

    func selectProperty(_ id: String) async throws {
        let result: PropertyOverview = try await api.get("/v1/properties/\(id)")
        overview = result
        UserDefaults.standard.set(id, forKey: propertyKey)
        dataVersion += 1
        if result.profile.setupCompleted {
            route = .main
        } else {
            route = .onboarding
            let step = OnboardingStep(rawValue: result.profile.setupStep)
            onboardingStep = (step?.isServerStep ?? false) ? step! : .website
        }
    }

    // MARK: Auth

    func signInWithApple(identityToken: String, rawNonce: String, fullName: String?, email: String?) async throws {
        let res: AuthResponse = try await api.request(
            "POST", "/v1/auth/apple",
            body: ["identityToken": .string(identityToken), "nonce": .string(rawNonce), "fullName": .from(fullName), "email": .from(email)] as [String: JSONValue],
            authenticated: false
        )
        await finishSignIn(res)
    }

    /// Device-bound sign-in for when Sign in with Apple isn't available (e.g. simulators).
    func signInOnDevice() async throws {
        var secret = Keychain.read("device_secret") ?? ""
        if secret.isEmpty {
            secret = AuthNonce.random(length: 48)
            Keychain.save(secret, for: "device_secret")
        }
        let res: AuthResponse = try await api.request(
            "POST", "/v1/auth/device",
            body: ["deviceSecret": .string(secret)] as [String: JSONValue],
            authenticated: false
        )
        await finishSignIn(res)
    }

    private func finishSignIn(_ res: AuthResponse) async {
        Keychain.save(res.token, for: "session_token")
        me = res.account
        await routeAfterSignIn()
    }

    func signOut() async {
        let _: OKResponse? = try? await api.post("/v1/auth/signout")
        clearSession()
    }

    func deleteAccount() async throws {
        let _: OKResponse = try await api.delete("/v1/me")
        Keychain.delete("device_secret")
        clearSession()
    }

    private func clearSession() {
        Keychain.delete("session_token")
        UserDefaults.standard.removeObject(forKey: propertyKey)
        me = nil
        overview = nil
        extraction = nil
        selectedTab = .today
        route = .onboarding
        onboardingStep = .welcome
    }

    // MARK: Property

    func createProperty(_ body: [String: JSONValue]) async throws {
        let result: PropertyOverview = try await api.post("/v1/properties", json: body)
        overview = result
        UserDefaults.standard.set(result.profile.id, forKey: propertyKey)
        me = try? await api.get("/v1/me")
        extraction = nil
        onboardingStep = .website
    }

    func acceptInvite(_ code: String) async throws {
        let clean = code.trimmed.uppercased().replacingOccurrences(of: " ", with: "")
        let result: InviteAcceptResponse = try await api.post("/v1/invites/\(clean)/accept")
        me = try? await api.get("/v1/me")
        try await selectProperty(result.propertyId)
    }

    func refreshOverview() async {
        guard propertyId != nil else { return }
        if let result: PropertyOverview = try? await api.get(path()) {
            overview = result
        }
    }

    @discardableResult
    func updateProfile(_ body: [String: JSONValue]) async throws -> Profile {
        let updated: Profile = try await api.patch(path("/profile"), json: body)
        overview?.profile = updated
        dataVersion += 1
        return updated
    }

    func syncBilling() async {
        guard propertyId != nil else { return }
        if let result: PropertyOverview = try? await api.post(path("/billing/sync")) {
            overview = result
            dataVersion += 1
        }
    }

    /// Call after any write that changes property data.
    func dataChanged() {
        dataVersion += 1
        Task { await refreshOverview() }
    }

    // MARK: Onboarding

    func goTo(_ step: OnboardingStep) {
        onboardingStep = step
        guard step.isServerStep, propertyId != nil else { return }
        let target = path("/setup-step")
        Task {
            let _: SetupStepResponse? = try? await api.post(target, json: ["step": .string(step.rawValue)])
        }
    }

    func completeSetup() async {
        let _: SetupStepResponse? = try? await api.post(path("/setup-step"), json: ["completed": .bool(true)])
        await refreshOverview()
        selectedTab = .today
        route = .main
    }

    func ask(_ question: String) {
        pendingQuestion = question
        selectedTab = .ask
    }
}
