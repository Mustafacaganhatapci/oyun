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

    /// YILDIZLA PREMIUM. Bu kadar yıldız toplayan oyuncuya premium kalıcı
    /// olarak veriliyor — ödeme yok, harcama da yok: yıldızlar oyuncuda
    /// kalıyor, küre eşikleri bozulmuyor. Oyundaki bütün eşikler gibi bu da
    /// GEÇİLDİĞİ AN açılıyor.
    ///
    /// Sayı neden 2600: kampanyanın tamamı 806 yıldız veriyor, yani bu eşik
    /// bölümleri bitirmekle tek başına geçilemiyor. Kalan ~1800 günlük ödül
    /// (seri dolduğunda 60/gün), görevler (3 × ~21/gün) ve ödüllü reklamlarla
    /// geliyor; düzenli oynayan biri için iki-üç hafta demek. Yeterince uzak
    /// ki satın almanın yerini almasın, yeterince yakın ki gerçek bir söz olsun.
    static let starPremiumThreshold = 2600

    @Published private(set) var isPremium: Bool
    @Published private(set) var isSupporter: Bool
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseInProgress = false
    @Published private(set) var productsLoaded = false   // ürün yükleme denemesi bitti mi

    /// Satın alma sonucu — sessizce başarısız olmak yerine arayüzde gösterilir.
    enum StatusMessage: Equatable { case success, pending, failed, restored, nothingToRestore }
    @Published var statusMessage: StatusMessage?

    /// Satın alma sonrası kişiye özel teşekkür kartı
    struct ThankYou: Equatable {
        enum Kind { case premium, tip, stars }
        let kind: Kind
    }
    @Published var thankYou: ThankYou?

    private var entitled = false        // gerçek IAP satın alması var mı
    private var promoGranted = false    // kodla açıldı mı
    private var starGranted = false     // yıldız eşiği geçilerek kazanıldı mı
    private var promoFailCount = 0
    private var promoBonusGranted = false
    private var updatesTask: Task<Void, Never>?

    init() {
        // Çevrimdışı açılışta arayüz doğru görünsün diye son bilinen durumu oku;
        // gerçek kaynak her zaman Transaction.currentEntitlements'tır.
        // Bahşiş ve kod hakları iCloud'da da tutuluyor: bahşiş tüketilebilir
        // bir ürün ve Apple onu geri yüklemiyor, kod da yalnızca girildiği
        // cihazda kalıyordu. İkisinden hangisi evet derse hak veriliyor.
        //
        // Önce YEREL değişkenlere alınıyor: `isSupporter` ve `isPremium` birer
        // @Published, yani okumak sarmalayıcının getter'ından geçiyor ve o da
        // self'in tamamen kurulmuş olmasını istiyor. init içinde birini okuyup
        // diğerine yazmak bu yüzden derlenmiyor.
        let premiumCache = UserDefaults.standard.bool(forKey: "lumo.store.premiumCache")
        let promo = UserDefaults.standard.bool(forKey: "lumo.store.promo")
            || EntitlementSync.shared.isPromoGranted
        let supporter = UserDefaults.standard.bool(forKey: "lumo.store.supporter")
            || EntitlementSync.shared.isSupporter
        // Yıldız eşiği yerelde tutuluyor; başka cihaza iCloud'la geçen şey
        // yıldızların KENDİSİ zaten (ProgressStore), eşik orada yeniden
        // geçiliyor ve hak kendiliğinden veriliyor.
        let stars = UserDefaults.standard.bool(forKey: Self.starGrantKey)

        entitled = premiumCache
        promoGranted = promo
        starGranted = stars
        isSupporter = supporter
        isPremium = premiumCache || promo || supporter || stars
        promoFailCount = UserDefaults.standard.integer(forKey: "lumo.store.promoFailCount")
        promoBonusGranted = UserDefaults.standard.bool(forKey: "lumo.store.promoBonusGranted")

        // Yerel kopyayı da tazele: bir cihazda alınan hak diğerinde iCloud'dan
        // gelmiş olabilir, bir dahaki açılışta çevrimdışıyken de dursun.
        if promoGranted { UserDefaults.standard.set(true, forKey: "lumo.store.promo") }
        if isSupporter { UserDefaults.standard.set(true, forKey: "lumo.store.supporter") }

        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }

        // Başka cihazda bahşiş bırakıldıysa oyun açıkken de düşsün
        EntitlementSync.shared.startObserving { [weak self] in
            self?.adoptCloudEntitlements()
        }
        Task {
            await loadProducts()
            await finishPendingTransactions()
            await refreshEntitlements()
        }
    }

    deinit { updatesTask?.cancel() }

    /// iCloud'dan yeni bir hak geldi. Yalnızca EKLER — buradan hiçbir hak
    /// geri alınmaz, çünkü boş bir iCloud "hakkın yok" demek değil,
    /// "henüz senkron olmadı" demek de olabilir.
    private func adoptCloudEntitlements() {
        var changed = false
        if EntitlementSync.shared.isSupporter, !isSupporter {
            isSupporter = true
            UserDefaults.standard.set(true, forKey: "lumo.store.supporter")
            changed = true
        }
        if EntitlementSync.shared.isPromoGranted, !promoGranted {
            promoGranted = true
            UserDefaults.standard.set(true, forKey: "lumo.store.promo")
            changed = true
        }
        if changed { recomputePremium() }
    }

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
        EntitlementSync.shared.markPromoGranted()
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
            // Gözlemci kipi: hakkı StoreKit veriyor, RevenueCat yalnızca
            // haberdar ediliyor. Kaydın başarısız olması satın almayı
            // etkilemez, o yüzden sonucuna bakılmıyor.
            await RevenueCatBridge.record(result)
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
        await restoreSupporterFromHistory()
        adoptCloudEntitlements()
        statusMessage = isPremium ? .restored : .nothingToRestore
    }

    /// Geçmişte bırakılmış bir bahşiş var mı? Apple tüketilebilirleri geri
    /// YÜKLEMİYOR ama işlem geçmişinde bir süre duruyorlar; duruyorsa hakkı
    /// buradan da geri veririz. Asıl güvence iCloud tarafı — bu ikinci bir
    /// ihtimal, bulursa kâr.
    private func restoreSupporterFromHistory() async {
        guard !isSupporter else { return }
        for await result in Transaction.all {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.tipSmallID
                    || transaction.productID == Self.tipSmallLegacyID
                    || transaction.productID == Self.tipBigID else { continue }
            guard transaction.revocationDate == nil else { continue }
            isSupporter = true
            UserDefaults.standard.set(true, forKey: "lumo.store.supporter")
            EntitlementSync.shared.markSupporter()
            recomputePremium()
            return
        }
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
                thankYou = .init(kind: .premium)
            }
        case Self.tipSmallID, Self.tipSmallLegacyID, Self.tipBigID:
            // Bahşiş bırakan da premium alır. Parasını oyunu desteklemek için
            // veren birine "bu da ayrıca satılıyor" demek nezaketsizlik olurdu.
            isSupporter = true
            UserDefaults.standard.set(true, forKey: "lumo.store.supporter")
            // Diğer cihazlarına da geçsin: bahşiş geri yüklenemeyen bir ürün
            EntitlementSync.shared.markSupporter()
            recomputePremium()
            record(productID: transaction.productID)
            thankYou = .init(kind: .tip)
        default:
            break
        }
    }

    /// premium = gerçek satın alma VEYA tanıdık kodu VEYA bahşiş VEYA yıldız eşiği
    private func recomputePremium() {
        isPremium = entitled || promoGranted || isSupporter || starGranted
        UserDefaults.standard.set(entitled, forKey: "lumo.store.premiumCache")
    }

    // MARK: Yıldızla premium

    private static let starGrantKey = "lumo.store.starPremium"

    /// Yıldız sayısı değiştiğinde çağrılır. Eşik geçildiyse premium'u kalıcı
    /// verir ve `true` döner.
    ///
    /// Yıldız HARCANMIYOR. Küreler de eşikle açılıyor ve harcama olsaydı
    /// premium'u alan oyuncu kürelerini geri kaybederdi; ayrıca "biriktirdiğin
    /// şey elinden alınıyor" hissi, ödülün kendisini cezaya çeviriyor.
    @discardableResult
    func checkStarUnlock(totalStars: Int) -> Bool {
        guard !starGranted, totalStars >= Self.starPremiumThreshold else { return false }
        // Zaten premium'u olana kutlama kartı ÇIKMIYOR: ona söylenecek yeni
        // bir şey yok. Hak yine de işaretleniyor, satın alması bir gün iade
        // edilse bile emeğiyle kazandığı yerinde kalsın.
        let announce = !isPremium
        starGranted = true
        UserDefaults.standard.set(true, forKey: Self.starGrantKey)
        recomputePremium()
        if announce { thankYou = .init(kind: .stars) }
        return announce
    }

    /// Eşiğe ne kadar kaldı — teklif ekranındaki çubuk bunu gösteriyor
    func starProgress(totalStars: Int) -> Double {
        min(1, Double(totalStars) / Double(Self.starPremiumThreshold))
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
