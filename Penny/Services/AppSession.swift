import Foundation
import SwiftUI
import StoreKit

/// Penny Pro product identifiers and free-tier limits.
///
/// Configure the same identifiers in App Store Connect and in `Penny.storekit`
/// for local testing. Pricing/localized names always come from StoreKit —
/// never hard-code prices.
enum PennyProductCatalog {
    /// Auto-renewing annual subscription (with an introductory free trial).
    static let annualProductID = "com.penny.app.pro.annual"
    /// One-time, non-consumable lifetime unlock.
    static let lifetimeProductID = "com.penny.app.pro.lifetime"

    static let allProductIDs: Set<String> = [annualProductID, lifetimeProductID]

    /// Free users can keep this many savings goals; adding more prompts Pro.
    static let freeTierGoalLimit = 3
}

/// StoreKit 2 façade that owns product loading, purchase, restore, and the
/// Penny Pro entitlement. Injected into the environment and long-lived for the
/// whole app session.
@Observable
@MainActor
final class StoreManager {
    private(set) var products: [Product] = []
    /// True when the user currently holds any Penny Pro entitlement.
    private(set) var isPro = false
    private(set) var isLoadingProducts = false
    private(set) var purchaseInFlight = false
    var lastErrorMessage: String?

    init() {
        // Listen for transactions that arrive outside an explicit purchase:
        // renewals, Ask-to-Buy approvals, and purchases made on other devices.
        Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    var annualProduct: Product? { products.first { $0.id == PennyProductCatalog.annualProductID } }
    var lifetimeProduct: Product? { products.first { $0.id == PennyProductCatalog.lifetimeProductID } }

    /// Load products and compute the current entitlement. Safe to call repeatedly.
    func start() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: PennyProductCatalog.allProductIDs)
            products = loaded.sorted { sortRank($0.id) < sortRank($1.id) }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func sortRank(_ id: String) -> Int {
        switch id {
        case PennyProductCatalog.annualProductID: return 0
        case PennyProductCatalog.lifetimeProductID: return 1
        default: return 2
        }
    }

    /// Recompute `isPro` from the user's current, non-revoked entitlements.
    func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if PennyProductCatalog.allProductIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        isPro = entitled
    }

    /// Returns true when the purchase completed and Pro is now active.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastErrorMessage = "This purchase could not be verified."
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                return isPro
            case .userCancelled:
                return false
            case .pending:
                lastErrorMessage = "Your purchase is pending approval."
                return false
            @unknown default:
                return false
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    /// Restore previous purchases (subscriptions + lifetime) across devices.
    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
        await refreshEntitlements()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await refreshEntitlements()
    }
}

/// Lightweight app-level preferences that complement SwiftData `UserSettings`.
@Observable
@MainActor
final class AppSession {
    var selectedMonth: Date = DateHelpers.startOfMonth()
    var showAddTransaction: Bool = false

    func resetMonth() {
        selectedMonth = DateHelpers.startOfMonth()
    }
}

enum SupportedCurrency: String, CaseIterable, Identifiable {
    case cad = "CAD"
    case usd = "USD"
    case gbp = "GBP"
    case eur = "EUR"
    case aud = "AUD"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cad: return "Canadian Dollar"
        case .usd: return "US Dollar"
        case .gbp: return "British Pound"
        case .eur: return "Euro"
        case .aud: return "Australian Dollar"
        }
    }

    var flag: String {
        switch self {
        case .cad: return "🇨🇦"
        case .usd: return "🇺🇸"
        case .gbp: return "🇬🇧"
        case .eur: return "🇪🇺"
        case .aud: return "🇦🇺"
        }
    }
}
