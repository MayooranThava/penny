import Foundation
import SwiftUI
import StoreKit

/// Penny Pro product identifiers and free-tier limits.
///
/// Configure the same identifiers in App Store Connect and in `Penny.storekit`
/// for local testing. Pricing/localized names always come from StoreKit —
/// never hard-code prices.
enum PennyProductCatalog {
    /// One-time, non-consumable lifetime unlock (current monetization).
    static let lifetimeProductID = "com.penny.app.pro.lifetime"

    /// Retired / do not sell: previously created in ASC as the wrong type (Consumable).
    /// Kept only so we never treat that ID as a Pro entitlement.
    static let retiredMonthlyConsumableProductID = "com.penny.app.pro.month"

    /// Product IDs loaded from StoreKit and accepted for Pro entitlement.
    static let allProductIDs: Set<String> = [lifetimeProductID]

    /// Free users can keep this many savings goals; adding more prompts Pro.
    static let freeTierGoalLimit = 3

    /// Free users can keep this many financial accounts; adding more prompts Pro.
    static let freeTierAccountLimit = 3

    /// Forecast months ahead available without Pro.
    static let freeTierForecastHorizons = [0, 1, 3]
    /// Forecast months ahead with Penny Pro (includes longer-range projections).
    static let proForecastHorizons = [0, 1, 3, 6, 12]

    static func forecastHorizons(isPro: Bool) -> [Int] {
        isPro ? proForecastHorizons : freeTierForecastHorizons
    }
}

/// Paywall and product lines the app shows. StoreKit still supplies the price
/// and the product name. `productNameFallback` is used only when that name is empty.
enum PaywallCopy {
    static let purchasesUnavailable = "Purchases are unavailable right now. Please try again later."
    static let productNameFallback = "Penny Pro"

    static func priceSubtitle(displayPrice: String) -> String {
        "\(displayPrice) · one-time purchase"
    }
}

/// A StoreKit product reduced to the fields the paywall displays.
/// Tests can build one without a StoreKit `Product`.
struct PennyOfferedProduct: Equatable, Identifiable, Sendable {
    var id: String
    var displayName: String
    var displayPrice: String
}

/// Result of a product load. Production fills both from StoreKit.
/// Tests can report offered products without constructing `Product`.
struct PennyLoadedCatalog {
    var products: [Product]
    var offered: [PennyOfferedProduct]

    init(products: [Product]) {
        self.products = products
        self.offered = products.map {
            PennyOfferedProduct(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice)
        }
    }

    init(offered: [PennyOfferedProduct]) {
        self.products = []
        self.offered = offered
    }
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
    private(set) var hasLoadedProducts = false
    private(set) var purchaseInFlight = false
    var lastErrorMessage: String?

    private(set) var offeredProducts: [PennyOfferedProduct] = []

    private let loadProductsFromStore: (Set<String>) async throws -> PennyLoadedCatalog

    init(
        loadProductsFromStore: @escaping (Set<String>) async throws -> PennyLoadedCatalog = { ids in
            PennyLoadedCatalog(products: try await Product.products(for: ids))
        },
        observeTransactionUpdates: Bool = true
    ) {
        self.loadProductsFromStore = loadProductsFromStore
        guard observeTransactionUpdates else { return }
        // Listen for transactions that arrive outside an explicit purchase:
        // renewals, Ask-to-Buy approvals, and purchases made on other devices.
        Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    /// Shown after a product request fails or returns nothing. Nil before that
    /// attempt finishes, while a load is in flight, or once a product is available,
    /// so the paywall is not left blank or spinning.
    var purchasesUnavailableMessage: String? {
        guard hasLoadedProducts, offeredProducts.isEmpty, !isLoadingProducts else { return nil }
        return PaywallCopy.purchasesUnavailable
    }

    var lifetimeProduct: Product? { products.first { $0.id == PennyProductCatalog.lifetimeProductID } }

    /// Load products and compute the current entitlement. Safe to call repeatedly.
    func start() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer {
            isLoadingProducts = false
            hasLoadedProducts = true
        }
        do {
            let loaded = try await loadProductsFromStore(PennyProductCatalog.allProductIDs)
            products = loaded.products.sorted { $0.id < $1.id }
            offeredProducts = loaded.offered.sorted { $0.id < $1.id }
            if offeredProducts.isEmpty {
                let productID = PennyProductCatalog.lifetimeProductID
                lastErrorMessage = "No products returned from the App Store. Confirm Penny Pro (\(productID)) is a Non-Consumable with a price, Paid Applications is Active, and you’re testing via TestFlight sandbox."
            } else {
                lastErrorMessage = nil
            }
        } catch {
            products = []
            offeredProducts = []
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Recompute `isPro` from the user's current, non-revoked entitlements.
    func refreshEntitlements() async {
        var entitled = false
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            // Never grant Pro for the retired consumable monthly ID.
            if transaction.productID == PennyProductCatalog.retiredMonthlyConsumableProductID {
                continue
            }
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

    /// Restore previous lifetime purchases across devices.
    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
        await refreshEntitlements()
    }

    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        await refreshEntitlements()
    }
}

/// Lightweight app-level preferences that complement SwiftData `UserSettings`.
@Observable
@MainActor
final class AppSession {
    enum MainTab: Int, Hashable, CaseIterable, Identifiable {
        case home, activity, budget, plan, settings
        var id: Int { rawValue }
    }

    var selectedMonth: Date = DateHelpers.startOfMonth()
    var selectedTab: MainTab = .home
    var showAddTransaction: Bool = false
    /// Drives the post-setup spotlight tour overlay.
    var showWalkthrough: Bool = false
    /// Which Plan segment the tour wants visible (e.g. Bills for “Add bill”).
    var walkthroughPlanSegment: PlanSegment? = nil
    /// Active spotlight target so Home can scroll the Upcoming section into view.
    var walkthroughAnchor: WalkthroughAnchorID? = nil

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
