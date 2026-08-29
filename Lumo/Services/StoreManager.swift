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
    static let tipSmallID = "lumo.tip.small2"
    /// İlk kimlik. Apple sildikten sonra bile kimliği kalıcı rezerve ettiği için
    /// küçük bahşiş `...small2`'ye taşınmıştı. App Store Connect'te hangisinin
    /// onaylı olduğu dışarıdan görülemiyor, o yüzden İKİSİ de sorulur ve hangisi
    /// dönerse o gösterilir. Yalnızca yenisini sormak, eski kimlik hâlâ onaylıysa
    /// bahşişin mağazada hiç görünmemesine yol açıyordu.
    static let tipSmallLegacyID = "lumo.tip.small"
    static let tipBigID = "lumo.tip.big"
    static let allIDs = [premiumID, tipSmallID, tipSmallLegacyID, tipBigID]

    static let tipSmallIDs: Set<String> = [tipSmallID, tipSmallLegacyID]

    /// Tanıdıklara verilen premium kodları (küçük harfe çevrilip karşılaştırılır,
    /// bu yüzden burada hepsi küçük harfle yazılır).
    static let promoCodes: Set<String> = ["axiumdynamicsisking", "ays123."]

    /// Kod 5'ten fazla kez yanlış girilirse (bir kereye mahsus) üzülmesin diye
    /// teselli olarak 100 yıldız verilir — premium'la hiçbir ilgisi yoktur.
    static let promoFailBonusThreshold = 5
    static let promoFailBonusStars = 100

    /// Ödüllü reklam sonunda verilen yıldız
    static let rewardedStarGrant = 25

    @Published private(set) var isPremium: Bool
    @Published private(set) var isSupporter: Bool
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseInProgress = false
    @Published private(set) var productsLoaded = false   // ürün yükleme denemesi bitti mi

    /// Satın alma sonucu — sessizce başarısız olmak yerine arayüzde gösterilir.
    enum StatusMessage: Equatable { case success, pending, failed, restored, nothingToRestore }
    @Published var statusMessage: StatusMessage?

    /// Satın alma sonrası kişiye özel teşekkür kartı
    struct ThankYou: Equatable { let isTip: Bool }
    @Published var thankYou: ThankYou?

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
            await finishPendingTransactions()
            await refreshEntitlements()
        }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: Self.allIDs)
            // Sabit sırada göster: premium, küçük bahşiş, büyük bahşiş.
            // İki küçük bahşiş kimliği de sorulduğu için ikisi birden dönerse
            // yalnızca ilki alınır; mağazada aynı bahşiş iki kez görünmez.
            var seenSmallTip = false
            products = Self.allIDs.compactMap { id -> Product? in
                guard let product = loaded.first(where: { $0.id == id }) else { return nil }
                if Self.tipSmallIDs.contains(id) {
                    if seenSmallTip { return nil }
                    seenSmallTip = true
                }
                return product
            }
            // Fiyatı önbelleğe al: çevrimdışı açılışta StoreKit ürün döndüremez
            // ama "premium ne kadar?" sorusuna yine de doğru yanıt verebilelim.
            if let premium = loaded.first(where: { $0.id == Self.premiumID }) {
                UserDefaults.standard.set(premium.displayPrice, forKey: Self.priceCacheKey)
            }
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
    ///
    /// Kodu önce koda gömülü listede, sonra Firestore'daki `promoCodes`
    /// koleksiyonunda arar.
    ///
    /// Gömülü liste sürüm gönderilmeden değiştirilemiyordu: birine kod vermek
    /// için yeni derleme çıkmak gerekiyordu. Firestore tarafı konsoldan anında
    /// yönetiliyor — kaç kez kullanılacağını, açık mı kapalı mı olduğunu sen
    /// belirliyorsun.
    func redeem(code: String) async -> Bool {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }

        // Gömülü liste önce: çevrimdışıyken de çalışsın
        if Self.promoCodes.contains(normalized) {
            grantPromo()
            return true
        }
        #if canImport(FirebaseCore)
        let playerID = UserDefaults.standard.string(forKey: "lumo.player.id") ?? "anonymous"
        if let accepted = await FirebaseBridge.redeemPromoCode(normalized, playerID: playerID),
           accepted {
            grantPromo()
            return true
        }
        #endif
        return false
    }

    private func grantPromo() {
        promoGranted = true
        UserDefaults.standard.set(true, forKey: "lumo.store.promo")
        recomputePremium()
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
        statusMessage = nil
        defer { purchaseInProgress = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    apply(transaction)
                    await transaction.finish()
                    statusMessage = .success
                case .unverified(let transaction, let error):
                    // İmza doğrulanamadı. İşlemi bitirmezsek kuyrukta kalır ve
                    // App Store aynı ürünü tekrar tekrar sormaya devam eder.
                    os_log(.error, "StoreKit doğrulanamayan işlem: %{public}@",
                           error.localizedDescription)
                    await transaction.finish()
                    statusMessage = .failed
                }
            case .userCancelled:
                break
            case .pending:
                // "Satın Alma İzni" (Ask to Buy) — onay bekleniyor
                statusMessage = .pending
            @unknown default:
                break
            }
        } catch {
            os_log(.error, "StoreKit satın alma hatası: %{public}@", error.localizedDescription)
            statusMessage = .failed
        }
    }

    /// Uygulama açılışında yarım kalmış işlemleri kapatır. Bitirilmemiş bir
    /// işlem kuyrukta durduğu sürece App Store aynı satın almayı yeniden sorar
    /// ve tüketilebilir ürünler bir daha satın alınamaz.
    private func finishPendingTransactions() async {
        for await result in Transaction.unfinished {
            switch result {
            case .verified(let transaction):
                apply(transaction)
                await transaction.finish()
            case .unverified(let transaction, _):
                await transaction.finish()
            }
        }
    }

    func restore() async {
        statusMessage = nil
        try? await AppStore.sync()
        await finishPendingTransactions()
        await refreshEntitlements()
        statusMessage = isPremium ? .restored : .nothingToRestore
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
            if transaction.revocationDate == nil {
                record(productID: transaction.productID)
                thankYou = .init(isTip: false)
            }
        case Self.tipSmallID, Self.tipSmallLegacyID, Self.tipBigID:
            // Bahşiş bırakan da premium alır. Parasını oyunu desteklemek için
            // veren birine "bu da ayrıca satılıyor" demek nezaketsizlik olurdu.
            isSupporter = true
            UserDefaults.standard.set(true, forKey: "lumo.store.supporter")
            recomputePremium()
            record(productID: transaction.productID)
            thankYou = .init(isTip: true)
        default:
            break
        }
    }

    /// premium = gerçek satın alma VEYA tanıdık kodu VEYA bahşiş
    private func recomputePremium() {
        isPremium = entitled || promoGranted || isSupporter
        UserDefaults.standard.set(entitled, forKey: "lumo.store.premiumCache")
    }

    // MARK: Destekçi kaydı
    //
    // Kim ne aldı bilinsin ki sonradan hediye premium/kod gönderilebilsin.
    // Kayıt Firestore'daki `supporters` koleksiyonuna gider; kurallar okumayı
    // istemciye KAPATIR, yalnızca konsoldan görünür.

    private func record(productID: String) {
        #if canImport(FirebaseCore)
        let defaults = UserDefaults.standard
        let playerID = defaults.string(forKey: "lumo.player.id") ?? "anonymous"
        let username = defaults.string(forKey: "lumo.player.username") ?? ""
        let price = products.first { $0.id == productID }?.displayPrice ?? ""
        Task {
            await FirebaseBridge.recordSupporter(playerID: playerID, username: username,
                                                 productID: productID, price: price)
        }
        #endif
    }

    var premiumProduct: Product? { products.first { $0.id == Self.premiumID } }

    private static let priceCacheKey = "lumo.store.premiumPrice"

    /// Premium'un gösterilecek fiyatı. Çevrimdışıyken StoreKit ürün
    /// döndüremediği için son bilinen fiyat kullanılır; hiç bilinmiyorsa nil
    /// döner ve arayüz fiyatsız metne geçer (asla sabit bir rakam yazmayız).
    var premiumPriceText: String? {
        premiumProduct?.displayPrice
            ?? UserDefaults.standard.string(forKey: Self.priceCacheKey)
    }
    var tipProducts: [Product] { products.filter { $0.id != Self.premiumID } }
}
