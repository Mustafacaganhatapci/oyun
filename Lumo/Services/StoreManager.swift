import Foundation
import StoreKit
import os.log

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

    /// Tanıdıklara verilen premium kodları (küçük harfe çevrilip karşılaştırılır).
    /// Bu kod gerçek satın alma yerine geçer; premium'u yerelde açar.
    static let promoCodes: Set<String> = ["axiumdynamicsisking"]

    /// Kod 5'ten fazla kez yanlış girilirse (bir kereye mahsus) üzülmesin diye
    /// teselli olarak 100 yıldız verilir — premium'la hiçbir ilgisi yoktur.
    static let promoFailBonusThreshold = 5
    static let promoFailBonusStars = 100

    @Published private(set) var isPremium: Bool
    @Published private(set) var isSupporter: Bool
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseInProgress = false
    @Published private(set) var productsLoaded = false   // ürün yükleme denemesi bitti mi

    private var entitled = false        // gerçek IAP satın alması var mı
    private var promoGranted = false    // kodla açıldı mı
    private var promoFailCount = 0
    private var promoBonusGranted = false
    private var updatesTask: Task<Void, Never>?

    init() {
        // Çevrimdışı açılışta arayüz doğru görünsün diye son bilinen durumu oku;
        // gerçek kaynak her zaman Transaction.currentEntitlements'tır.
        entitled = UserDefaults.standard.bool(forKey: "lumo.store.premiumCache")
        promoGranted = UserDefaults.standard.bool(forKey: "lumo.store.promo")
        isPremium = entitled || promoGranted
        isSupporter = UserDefaults.standard.bool(forKey: "lumo.store.supporter")
        promoFailCount = UserDefaults.standard.integer(forKey: "lumo.store.promoFailCount")
        promoBonusGranted = UserDefaults.standard.bool(forKey: "lumo.store.promoBonusGranted")

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
            // Console.app'te "Orbeon" ile filtrele: kaç ürün geldi görebilirsin.
            // 0 ise ürünler App Store Connect'te hazır değil / sözleşme aktif değil.
            os_log(.info, "StoreKit: %d ürün yüklendi (%{public}@)",
                   products.count, products.map { $0.id }.joined(separator: ", "))
        } catch {
            products = []
            os_log(.error, "StoreKit ürün yükleme hatası: %{public}@", error.localizedDescription)
        }
        productsLoaded = true
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
        entitled = premium
        recomputePremium()
    }

    /// Tanıdık kodunu dener. Geçerliyse premium'u kalıcı açar ve true döner.
    @discardableResult
    func redeem(code: String) -> Bool {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.promoCodes.contains(normalized) else { return false }
        promoGranted = true
        UserDefaults.standard.set(true, forKey: "lumo.store.promo")
        recomputePremium()
        return true
    }

    /// Yanlış kod girildiğinde çağrılır. Eşiği aşan İLK denemede (bir kereye
    /// mahsus) true döner — arayüz bu durumda teselli yıldızlarını verir.
    @discardableResult
    func recordFailedPromoAttempt() -> Bool {
        promoFailCount += 1
        UserDefaults.standard.set(promoFailCount, forKey: "lumo.store.promoFailCount")
        guard promoFailCount > Self.promoFailBonusThreshold, !promoBonusGranted else { return false }
        promoBonusGranted = true
        UserDefaults.standard.set(true, forKey: "lumo.store.promoBonusGranted")
        return true
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
            os_log(.error, "StoreKit satın alma hatası: %{public}@", error.localizedDescription)
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
            entitled = transaction.revocationDate == nil
            recomputePremium()
        case Self.tipSmallID, Self.tipBigID:
            isSupporter = true
            UserDefaults.standard.set(true, forKey: "lumo.store.supporter")
        default:
            break
        }
    }

    /// premium = gerçek satın alma VEYA tanıdık kodu
    private func recomputePremium() {
        isPremium = entitled || promoGranted
        UserDefaults.standard.set(entitled, forKey: "lumo.store.premiumCache")
    }

    var premiumProduct: Product? { products.first { $0.id == Self.premiumID } }
    var tipProducts: [Product] { products.filter { $0.id != Self.premiumID } }
}
