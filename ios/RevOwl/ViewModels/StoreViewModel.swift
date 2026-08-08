import Foundation
import Observation
import RevenueCat

/// Manages RevenueCat offerings, subscription entitlements, and the consumable credits purchase flow.
@Observable
@MainActor
final class StoreViewModel {
    var offerings: Offerings?
    /// Tier derived from active RevenueCat entitlements. Scout when nothing is active.
    var entitledTier: SubscriptionTier = .scout
    var creditsBalance: Int = UserDefaults.standard.integer(forKey: StoreViewModel.creditsBalanceKey)
    var isLoading: Bool = false
    var isPurchasing: Bool = false
    var isRestoring: Bool = false
    var errorMessage: String?
    var lastGrantedCredits: Int?

    /// Credits granted per $1 pack purchase.
    static let creditsPerPack = 100

    private static let creditsBalanceKey = "creditsBalance"

    init() {
        Task { await fetchOfferings() }
        Task { await refreshEntitlements() }
        Task { await listenForCustomerInfo() }
    }

    // MARK: - Offerings

    /// The $1 credits package from the "credits" offering.
    var creditsPackage: Package? {
        offerings?.offering(identifier: "credits")?.availablePackages.first
    }

    /// The monthly subscription package for a paid tier from the "plans" offering.
    func package(for tier: SubscriptionTier) -> Package? {
        guard let plans = offerings?.offering(identifier: "plans") else { return nil }
        switch tier {
        case .scout: return nil
        case .growth: return plans.package(identifier: "growth_monthly")
        case .pro: return plans.package(identifier: "pro_monthly")
        }
    }

    /// Localized store price for a tier, falling back to the static display price.
    func priceText(for tier: SubscriptionTier) -> String {
        guard tier != .scout else { return "Free" }
        if let localized = package(for: tier)?.storeProduct.localizedPriceString {
            return "\(localized)/mo"
        }
        return tier.price
    }

    func fetchOfferings() async {
        isLoading = true
        defer { isLoading = false }
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            errorMessage = "Couldn't load products. Check your connection and try again."
            print("[Store] Failed to fetch offerings: \(error.localizedDescription)")
        }
    }

    // MARK: - Entitlements

    private func listenForCustomerInfo() async {
        for await info in Purchases.shared.customerInfoStream {
            applyEntitlements(info)
        }
    }

    func refreshEntitlements() async {
        if let info = try? await Purchases.shared.customerInfo() {
            applyEntitlements(info)
        }
    }

    private func applyEntitlements(_ info: CustomerInfo) {
        if info.entitlements["pro"]?.isActive == true {
            entitledTier = .pro
        } else if info.entitlements["growth"]?.isActive == true {
            entitledTier = .growth
        } else {
            entitledTier = .scout
        }
    }

    // MARK: - Purchases

    /// Purchases the monthly subscription for a paid tier. Returns true on success.
    @discardableResult
    func purchase(tier: SubscriptionTier) async -> Bool {
        guard tier != .scout else { return true }
        guard let package = package(for: tier) else {
            errorMessage = "That plan is unavailable right now. Please try again later."
            return false
        }
        return await purchase(package: package) != nil
    }

    /// Purchases the consumable credits pack and grants credits on success.
    func purchaseCredits() async {
        guard let package = creditsPackage else {
            errorMessage = "Credits pack is unavailable right now. Please try again later."
            return
        }
        if await purchase(package: package) != nil {
            grantCredits(Self.creditsPerPack)
            lastGrantedCredits = Self.creditsPerPack
        }
    }

    /// Shared purchase pipeline. Returns customer info on success, nil on cancel/failure.
    private func purchase(package: Package) async -> CustomerInfo? {
        guard !isPurchasing else { return nil }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return nil }
            applyEntitlements(result.customerInfo)
            return result.customerInfo
        } catch ErrorCode.purchaseCancelledError {
            // User cancelled — not an error.
            return nil
        } catch ErrorCode.paymentPendingError {
            errorMessage = "Your purchase is pending approval. It will activate once it completes."
            return nil
        } catch {
            errorMessage = "Purchase failed. Please try again."
            print("[Store] Purchase failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Restores previous purchases and re-applies entitlements.
    func restore() async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            applyEntitlements(info)
        } catch {
            errorMessage = "Restore failed. Please try again."
            print("[Store] Restore failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Credits balance

    /// Deducts credits if the balance allows it. Returns false when insufficient.
    @discardableResult
    func spendCredits(_ amount: Int) -> Bool {
        guard amount > 0, creditsBalance >= amount else { return false }
        creditsBalance -= amount
        persistBalance()
        return true
    }

    private func grantCredits(_ amount: Int) {
        creditsBalance += amount
        persistBalance()
    }

    private func persistBalance() {
        UserDefaults.standard.set(creditsBalance, forKey: Self.creditsBalanceKey)
    }
}
