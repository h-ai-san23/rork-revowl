import Foundation
import Observation
import RevenueCat

/// RevenueCat purchases. Subscriptions belong to a property: the RevenueCat app user id is
/// the property id, and the backend re-verifies entitlements with RevenueCat.
@Observable
@MainActor
final class StoreViewModel {
    var offering: Offering?
    var isLoading = false
    var purchasingPlanId: String?
    var isRestoring = false
    var errorMessage: String?
    /// Product id → eligible for the introductory free trial (StoreKit-determined).
    var introEligible: [String: Bool] = [:]
    private(set) var activePropertyId: String?

    func activate(propertyId: String?) async {
        guard let propertyId, propertyId != activePropertyId else { return }
        do {
            _ = try await Purchases.shared.logIn(propertyId)
            activePropertyId = propertyId
        } catch {
            errorMessage = "The App Store connection isn't ready yet. Plans may take a moment to load."
        }
        await loadOfferings()
    }

    func deactivate() async {
        guard activePropertyId != nil else { return }
        activePropertyId = nil
        _ = try? await Purchases.shared.logOut()
    }

    func loadOfferings() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            offering = offerings.offering(identifier: "hotel_plans") ?? offerings.current
            let ids = offering?.availablePackages.map { $0.storeProduct.productIdentifier } ?? []
            if !ids.isEmpty {
                let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: ids)
                introEligible = result.mapValues { $0.status == .eligible }
            }
        } catch {
            errorMessage = "Plans couldn't be loaded from the App Store. Please try again."
        }
    }

    func package(for planId: String) -> Package? {
        guard let offering else { return nil }
        return offering.package(identifier: "\(planId)_monthly")
            ?? offering.availablePackages.first { $0.storeProduct.productIdentifier.hasPrefix("revowl_\(planId)") }
    }

    /// True when StoreKit reports a free-trial intro offer the user can still redeem.
    func offersTrial(_ planId: String, serverTrialUsed: Bool) -> Bool {
        guard !serverTrialUsed, let product = package(for: planId)?.storeProduct,
              let intro = product.introductoryDiscount, intro.paymentMode == .freeTrial else { return false }
        return introEligible[product.productIdentifier] ?? false
    }

    func trialLength(_ planId: String) -> String? {
        guard let intro = package(for: planId)?.storeProduct.introductoryDiscount else { return nil }
        let value = intro.subscriptionPeriod.value
        switch intro.subscriptionPeriod.unit {
        case .day: return value == 7 ? "1-week" : "\(value)-day"
        case .week: return value == 1 ? "1-week" : "\(value)-week"
        case .month: return "\(value)-month"
        case .year: return "\(value)-year"
        @unknown default: return nil
        }
    }

    /// Returns true when a purchase completed (not cancelled, not pending).
    func purchase(planId: String) async -> Bool {
        guard let pkg = package(for: planId) else {
            errorMessage = "This plan isn't available from the App Store yet."
            return false
        }
        purchasingPlanId = planId
        defer { purchasingPlanId = nil }
        do {
            let result = try await Purchases.shared.purchase(package: pkg)
            return !result.userCancelled
        } catch ErrorCode.purchaseCancelledError {
            return false
        } catch ErrorCode.paymentPendingError {
            errorMessage = "Your purchase is waiting for approval. We'll unlock your plan as soon as it's confirmed."
            return false
        } catch {
            errorMessage = "The purchase didn't go through. You haven't been charged."
            return false
        }
    }

    func restore() async -> Bool {
        isRestoring = true
        defer { isRestoring = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            if info.entitlements.active.isEmpty {
                errorMessage = "No active subscription was found for this Apple ID."
                return false
            }
            return true
        } catch {
            errorMessage = "Purchases couldn't be restored. Please try again."
            return false
        }
    }
}
