import Foundation
import StoreKit

/// StoreKit 2 tabanlı satın alma yöneticisi.
/// Ürünler:
///  - lumo.premium     (kalıcı): tüm reklamları kaldırır + 4 premium tema + destekçi rozeti
///  - lumo.tip.small   (tüketilebilir): geliştiriciye küçük bahşiş
///  - lumo.tip.big     (tüketilebilir): geliştiriciye büyük bahşiş
/// Hiçbir ürün oynanış avantajı vermez — pay-to-win yoktur.
@MainActor
final class StoreManager: ObservableObject {
    static let premiumID = "lumo.premium"
    static let tipSmallID = "lumo.tip.small"
    static let tipBigID = "lumo.tip.big"
    static let allIDs = [premiumID, tipSmallID, tipBigID]

    @Published private(set) var isPremium: Bool
    @Published private(set) var isSupporter: Bool
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseInProgress = false

    private var updatesTask: Task<Void, Never>?

    init() {
        // Çevrimdışı açılışta arayüz doğru görünsün diye son bilinen durumu oku;
        // gerçek kaynak her zaman Transaction.currentEntitlements'tır.
        isPremium = UserDefaults.standard.bool(forKey: "lumo.store.premiumCache")
        isSupporter = UserDefaults.standard.bool(forKey: "lumo.store.supporter")

        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: Self.allIDs)
            // Sabit sırada göster: premium, küçük bahşiş, büyük bahşiş
            products = Self.allIDs.compactMap { id in loaded.first { $0.id == id } }
        } catch {
            products = []
        }
    }

    func refreshEntitlements() async {
        var premium = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.premiumID,
               transaction.revocationDate == nil {
                premium = true
            }
        }
        setPremium(premium)
    }

    func purchase(_ product: Product) async {
        guard !purchaseInProgress else { return }
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    apply(transaction)
                    await transaction.finish()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            // Satın alma hatası: sessizce yut, arayüz mevcut durumda kalır
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func handle(_ update: VerificationResult<Transaction>) async {
        if case .verified(let transaction) = update {
            apply(transaction)
            await transaction.finish()
        }
    }

    private func apply(_ transaction: Transaction) {
        switch transaction.productID {
        case Self.premiumID:
            setPremium(transaction.revocationDate == nil)
        case Self.tipSmallID, Self.tipBigID:
            isSupporter = true
            UserDefaults.standard.set(true, forKey: "lumo.store.supporter")
        default:
            break
        }
    }

    private func setPremium(_ value: Bool) {
        isPremium = value
        UserDefaults.standard.set(value, forKey: "lumo.store.premiumCache")
    }

    var premiumProduct: Product? { products.first { $0.id == Self.premiumID } }
    var tipProducts: [Product] { products.filter { $0.id != Self.premiumID } }
}
