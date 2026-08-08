import Foundation
import Observation
import RevenueCat

/// Manages RevenueCat offerings and the consumable credits purchase flow.
@Observable
@MainActor
final class StoreViewModel {
    var offerings: Offerings?
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
    }

    /// The $1 credits package from the "credits" offering.
    var creditsPackage: Package? {
        offerings?.offering(identifier: "credits")?.availablePackages.first
            ?? offerings?.current?.availablePackages.first
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

    /// Purchases the consumable credits pack and grants credits on success.
    func purchaseCredits() async {
        guard let package = creditsPackage else {
            errorMessage = "Credits pack is unavailable right now. Please try again later."
            return
        }
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                grantCredits(Self.creditsPerPack)
                lastGrantedCredits = Self.creditsPerPack
            }
        } catch ErrorCode.purchaseCancelledError {
            // User cancelled — not an error.
        } catch ErrorCode.paymentPendingError {
            errorMessage = "Your purchase is pending approval. Credits will be added once it completes."
        } catch {
            errorMessage = "Purchase failed. Please try again."
            print("[Store] Purchase failed: \(error.localizedDescription)")
        }
    }

    /// Restores non-consumable purchases and subscriptions. Consumed credits are
    /// device-local and are not returned by StoreKit restore.
    func restore() async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            _ = try await Purchases.shared.restorePurchases()
        } catch {
            errorMessage = "Restore failed. Please try again."
            print("[Store] Restore failed: \(error.localizedDescription)")
        }
    }

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
