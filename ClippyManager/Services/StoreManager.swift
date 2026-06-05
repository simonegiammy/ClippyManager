import Foundation
import StoreKit
import Observation

/// StoreKit 2 wrapper for the one-time lifetime unlock.
///
/// This is scaffolding: it does nothing harmful until a Non-Consumable product
/// with id `LicenseManager.lifetimeProductID` exists in App Store Connect.
/// Until then `product` stays nil and the UI shows the fallback price.
@Observable
@MainActor
final class StoreManager {
    private let license: LicenseManager

    var product: Product?
    var isLoading = false
    var lastError: String?

    private var updatesTask: Task<Void, Never>?

    init(license: LicenseManager) {
        self.license = license
        updatesTask = listenForTransactions()
    }

    var displayPrice: String {
        product?.displayPrice ?? LicenseManager.displayPrice
    }

    // MARK: - Loading

    func loadProduct() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [LicenseManager.lifetimeProductID])
            product = products.first
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
    }

    // MARK: - Purchase

    /// Returns true when the lifetime unlock is owned after this call.
    @discardableResult
    func purchase() async -> Bool {
        guard let product else {
            lastError = "Product not available yet. Configure the IAP in App Store Connect."
            return false
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    license.unlockWithPurchase()
                    return true
                }
                lastError = "Purchase could not be verified."
                return false
            case .userCancelled:
                return false
            case .pending:
                lastError = "Purchase is pending approval."
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Restore a previous purchase (App Store sync + entitlement check).
    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == LicenseManager.lifetimeProductID,
               transaction.revocationDate == nil {
                license.unlockWithPurchase()
            }
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                if case .verified(let transaction) = update,
                   transaction.productID == LicenseManager.lifetimeProductID {
                    await transaction.finish()
                    await MainActor.run { self.license.unlockWithPurchase() }
                }
            }
        }
    }
}
