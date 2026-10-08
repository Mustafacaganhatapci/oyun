package com.caganhatapci.orbeon.services

import android.app.Activity
import android.content.Context
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ConsumeParams
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.caganhatapci.orbeon.store.prefs
import java.util.Calendar

/**
 * Google Play Faturalandırma — iOS'taki StoreManager'ın karşılığı.
 *
 * Ürünler:
 *  - orbeon.premium   (kalıcı): tüm reklamları kaldırır + premium temalar
 *  - orbeon.tip.small (tüketilebilir): geliştiriciye küçük bahşiş
 *  - orbeon.tip.big   (tüketilebilir): geliştiriciye büyük bahşiş
 *
 * Hiçbir ürün oynanış avantajı vermez — pay-to-win yoktur.
 */
class BillingManager(private val context: Context) {

    companion object {
        const val PREMIUM_ID = "orbeon.premium"
        const val TIP_SMALL_ID = "orbeon.tip.small"
        const val TIP_BIG_ID = "orbeon.tip.big"

        /** Ödüllü reklam sonunda verilen yıldız */
        const val REWARDED_STAR_GRANT = 25

        /**
         * YILDIZLA PREMIUM. Bu kadar yıldız toplayana premium kalıcı veriliyor
         * — ödeme yok, harcama da yok.
         *
         * Sayı neden 2600: kampanyanın tamamı 806 yıldız veriyor, yani bu eşik
         * bölümleri bitirmekle tek başına geçilemiyor. Kalanı günlük ödül,
         * görevler ve ödüllü reklamlarla geliyor; düzenli oynayan için iki-üç
         * hafta. Yeterince uzak ki satın almanın yerini almasın, yeterince
         * yakın ki gerçek bir söz olsun.
         */
        const val STAR_PREMIUM_THRESHOLD = 2600

        /** 6 Ekim 2026 — Calendar'da ay SIFIR TABANLI, yani 9 = Ekim */
        const val PRICE_HOLD_END_YEAR = 2026
        const val PRICE_HOLD_END_MONTH = 9
        const val PRICE_HOLD_END_DAY = 6

        /** Tanıdıklara verilen premium kodları (küçük harfe çevrilip karşılaştırılır) */
        val PROMO_CODES = setOf("axiumdynamicsisking", "ays123.")

        /**
         * SÜRELİ deneme kodları: kod → kaç gün premium.
         *
         * Kalıcı premium veren PROMO_CODES'tan ayrı tutuluyor, çünkü üç farkı
         * var: süresi dolar, kullanıcı başına BİR KEZ verilir ve süresi
         * dolduktan sonra aynı kod bir daha çalışmaz.
         *
         * Koda gömülü, Firestore'a sorulmuyor: tanıtım kodunun çevrimdışı da
         * çalışması gerekiyor ve sınır kişi başına, toplam kullanıma değil.
         */
        val TRIAL_PROMO_CODES = mapOf("ictenmimar100" to 10)

        /**
         * Kodu karşılaştırmaya hazırlar: Türkçe harfleri ASCII karşılığına
         * indirger, harf ve rakam dışındaki her şeyi atar, küçük harfe çevirir.
         *
         * Buna ihtiyaç var çünkü düz `lowercase()` üç ayrı yerde patlıyordu:
         *
         *  1. `lowercase()` CİHAZIN DİLİNİ kullanıyor. Türkçe telefonda
         *     "ICTENMIMAR100" → "ıctenmımar100" (noktasız ı) oluyor ve hiçbir
         *     zaman eşleşmiyordu. Oyunun ana kitlesi Türkçe, yani bu hata
         *     kodu çoğu kullanıcı için bozuyordu.
         *  2. Kodun markası "İçten Mimar" — insan doğal olarak
         *     `içtenmimar100` yazıyor, bizdeki `c` ise düz.
         *  3. Boşluk ve noktalama: kopyala-yapıştırda araya boşluk giriyor.
         *
         * Noktalama atıldığı için `ays123.` ile `ays123` artık aynı şey.
         */
        fun normalizeCode(raw: String): String {
            val sb = StringBuilder(raw.length)
            for (ch in raw) when (ch) {
                'ı', 'İ', 'I', 'i' -> sb.append('i')
                'ş', 'Ş' -> sb.append('s')
                'ğ', 'Ğ' -> sb.append('g')
                'ç', 'Ç' -> sb.append('c')
                'ö', 'Ö' -> sb.append('o')
                'ü', 'Ü' -> sb.append('u')
                // Birleşen nokta (U+0307) ve diğer işaretler burada eleniyor
                else -> if (ch.isLetterOrDigit()) sb.append(ch)
            }
            // Locale.ROOT ŞART: varsayılan yerel kullanılırsa 1. maddedeki
            // hata geri gelir.
            return sb.toString().lowercase(java.util.Locale.ROOT)
        }
        const val PROMO_FAIL_BONUS_THRESHOLD = 5
        const val PROMO_FAIL_BONUS_STARS = 100

        private const val TAG = "Orbeon.Billing"
        private const val KEY_PREMIUM_PRICE = "billing.premiumPrice"
        private const val KEY_TRIAL_UNTIL = "store.trialUntil"
    }

    enum class Status { SUCCESS, PENDING, FAILED, RESTORED, NOTHING_TO_RESTORE }

    /** Satın alma sonrası kişiye özel teşekkür kartı */
    /**
     * Premium'a kavuşulan anın kartı. Üç yolu var ve üçü aynı yere çıkmıyor:
     * satın alan bir şey aldı, bahşiş bırakan karşılık beklemeden verdi,
     * yıldızla açan ise ödemedi — oynadı.
     */
    data class ThankYou(val kind: Kind) {
        enum class Kind { PREMIUM, TIP, STARS }
    }

    var thankYou by mutableStateOf<ThankYou?>(null)

    var isPremium by mutableStateOf(false)
        private set
    var isSupporter by mutableStateOf(false)
        private set
    var products by mutableStateOf<List<ProductDetails>>(emptyList())
        private set
    var productsLoaded by mutableStateOf(false)
        private set
    var purchaseInProgress by mutableStateOf(false)
        private set
    var statusMessage by mutableStateOf<Status?>(null)

    private val p = prefs(context)
    private var entitled = false      // gerçek satın alma var mı
    private var promoGranted = false  // kodla açıldı mı
    private var starGranted = false   // yıldız eşiği geçilerek kazanıldı mı
    private var promoFailCount = 0
    private var promoBonusGranted = false
    /**
     * Süreli denemenin bitiş anı (epoch ms). 0 = hiç kullanılmadı.
     * GEÇMİŞ bir değer de "kullanıldı" sayılır: hak bitmiştir ama kod da
     * harcanmıştır, aynı kişiye ikinci bir on gün verilmez. Değer
     * orbeon.prefs.xml'de ve o dosya Google yedeğine dahil, yani telefon
     * değişince deneme yeniden başlamıyor.
     */
    private var trialUntil = 0L

    val premiumProduct: ProductDetails? get() = products.firstOrNull { it.productId == PREMIUM_ID }

    /**
     * Premium'un gösterilecek fiyatı. Çevrimdışıyken Play ürün döndüremediği
     * için son bilinen fiyat kullanılır; hiç bilinmiyorsa null döner ve arayüz
     * fiyatsız metne geçer (asla sabit bir rakam yazmayız).
     */
    val premiumPriceText: String?
        get() = premiumProduct?.oneTimePurchaseOfferDetails?.formattedPrice
            ?: p.getString(KEY_PREMIUM_PRICE, null)
    val tipProducts: List<ProductDetails> get() = products.filter { it.productId != PREMIUM_ID }

    private val client: BillingClient = BillingClient.newBuilder(context)
        .setListener { result, purchases ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
                purchases.forEach { handlePurchase(it) }
                statusMessage = Status.SUCCESS
            } else if (result.responseCode == BillingClient.BillingResponseCode.USER_CANCELED) {
                // sessizce geç — kullanıcı vazgeçti
            } else {
                Log.e(TAG, "Satın alma hatası: ${result.debugMessage}")
                statusMessage = Status.FAILED
            }
            purchaseInProgress = false
        }
        .enablePendingPurchases(
            PendingPurchasesParams.newBuilder().enableOneTimeProducts().build()
        )
        .build()

    init {
        // Çevrimdışı açılışta arayüz doğru görünsün diye son bilinen durumu oku;
        // gerçek kaynak her zaman Play'in satın alma listesidir.
        entitled = p.getBoolean("store.premiumCache", false)
        promoGranted = p.getBoolean("store.promo", false)
        isSupporter = p.getBoolean("store.supporter", false)
        starGranted = p.getBoolean("store.starPremium", false)
        promoFailCount = p.getInt("store.promoFailCount", 0)
        promoBonusGranted = p.getBoolean("store.promoBonusGranted", false)
        trialUntil = p.getLong(KEY_TRIAL_UNTIL, 0L)
        recomputePremium()
        connect()
    }

    private fun connect() {
        client.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    loadProducts()
                    refreshEntitlements()
                } else {
                    Log.e(TAG, "Play bağlantısı kurulamadı: ${result.debugMessage}")
                    productsLoaded = true
                }
            }

            override fun onBillingServiceDisconnected() {
                // Play servisi düştü; bir sonraki işlemde yeniden bağlanmayı dener
                Log.w(TAG, "Play servisi bağlantısı koptu")
            }
        })
    }

    private fun loadProducts() {
        val ids = listOf(PREMIUM_ID, TIP_SMALL_ID, TIP_BIG_ID)
        val productList = ids.map {
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(it)
                .setProductType(BillingClient.ProductType.INAPP)
                .build()
        }
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(productList)
            .build()

        // Faturalandırma 8'de geri çağrının ikinci parametresi artık düz bir
        // List<ProductDetails> değil, QueryProductDetailsResult. Çekilebilen
        // ürünler `productDetailsList`te; çekilemeyenler eskiden sessizce
        // düşüyordu, artık `unfetchedProductList`te sebebiyle geliyor.
        client.queryProductDetailsAsync(params) { result, details ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                val list = details.productDetailsList
                // Sabit sırada göster: premium, küçük bahşiş, büyük bahşiş
                products = ids.mapNotNull { id -> list.firstOrNull { it.productId == id } }
                // Fiyatı önbelleğe al: çevrimdışıyken Play ürün döndüremez ama
                // "premium ne kadar?" sorusuna yine de doğru yanıt verebilelim.
                premiumProduct?.oneTimePurchaseOfferDetails?.formattedPrice?.let {
                    p.edit().putString(KEY_PREMIUM_PRICE, it).apply()
                }
                // Eksik ürünün sebebi artık öğrenilebiliyor: Play Console'da
                // etkin değil, ülkede satılmıyor, kimlik yanlış yazılmış…
                for (u in details.unfetchedProductList) {
                    Log.e(TAG, "Ürün çekilemedi: ${u.productId} (${u.statusCode})")
                }
            } else {
                Log.e(TAG, "Ürünler yüklenemedi: ${result.debugMessage}")
                products = emptyList()
            }
            // Logcat'te "Orbeon.Billing" ile filtrele: 0 ise ürünler Play
            // Console'da hazır değil ya da uygulama henüz yayınlanmamıştır.
            Log.i(TAG, "Play: ${products.size} ürün yüklendi (${products.joinToString { it.productId }})")
            productsLoaded = true
        }
    }

    fun refreshEntitlements() {
        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.INAPP)
            .build()
        client.queryPurchasesAsync(params) { result, purchases ->
            if (result.responseCode != BillingClient.BillingResponseCode.OK) return@queryPurchasesAsync
            var premium = false
            purchases.forEach { purchase ->
                if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED) {
                    if (purchase.products.contains(PREMIUM_ID)) premium = true
                    handlePurchase(purchase)
                }
            }
            entitled = premium
            recomputePremium()
        }
    }

    fun purchase(activity: Activity, product: ProductDetails) {
        if (purchaseInProgress) return
        purchaseInProgress = true
        statusMessage = null
        val params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(
                listOf(
                    BillingFlowParams.ProductDetailsParams.newBuilder()
                        .setProductDetails(product)
                        .build()
                )
            )
            .build()
        val result = client.launchBillingFlow(activity, params)
        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
            Log.e(TAG, "Satın alma akışı açılamadı: ${result.debugMessage}")
            statusMessage = Status.FAILED
            purchaseInProgress = false
        }
    }

    fun restore() {
        statusMessage = null
        refreshEntitlements()
        statusMessage = if (isPremium) Status.RESTORED else Status.NOTHING_TO_RESTORE
    }

    /**
     * Satın almayı işler. Onaylanmamış (acknowledge edilmemiş) bir satın alma
     * Play tarafından 3 gün sonra iade edilir; tüketilebilirler tüketilmezse
     * bir daha satın alınamaz. İkisi de burada kapatılır.
     */
    private fun handlePurchase(purchase: Purchase) {
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) {
            if (purchase.purchaseState == Purchase.PurchaseState.PENDING) {
                statusMessage = Status.PENDING
            }
            return
        }

        when {
            purchase.products.contains(PREMIUM_ID) -> {
                entitled = true
                recomputePremium()
                record(PREMIUM_ID)
                thankYou = ThankYou(ThankYou.Kind.PREMIUM)
                if (!purchase.isAcknowledged) {
                    val params = AcknowledgePurchaseParams.newBuilder()
                        .setPurchaseToken(purchase.purchaseToken)
                        .build()
                    client.acknowledgePurchase(params) { }
                }
            }
            else -> {
                // Bahşiş bırakan da premium alır. Parasını oyunu desteklemek
                // için veren birine "bu da ayrıca satılıyor" demek
                // nezaketsizlik olurdu.
                isSupporter = true
                p.edit().putBoolean("store.supporter", true).apply()
                recomputePremium()
                record(purchase.products.firstOrNull() ?: TIP_SMALL_ID)
                thankYou = ThankYou(ThankYou.Kind.TIP)
                // Bahşişler tüketilebilir: tekrar tekrar verilebilmeli
                val params = ConsumeParams.newBuilder()
                    .setPurchaseToken(purchase.purchaseToken)
                    .build()
                client.consumeAsync(params) { _, _ -> }
            }
        }
    }

    /**
     * Tanıdık kodunu dener. Geçerliyse premium'u kalıcı açar.
     *
     * Önce koda gömülü listeye bakar (çevrimdışı da çalışsın), sonra
     * Firestore'daki `promoCodes` koleksiyonuna sorar. İkincisi konsoldan
     * anında yönetiliyor: kod vermek için yeni sürüm çıkmak gerekmiyor.
     */
    /**
     * Kod denemesinin sonucu. Eskiden düz Boolean'dı; süreli deneme gelince
     * "kabul edilmedi"nin iki ayrı sebebi oldu ve oyuncuya hangisi olduğunu
     * söylemek gerekiyor — "geçersiz kod" ile "bu kodu zaten kullandın"
     * aynı şey değil.
     */
    enum class RedeemResult { PREMIUM, TRIAL, TRIAL_ALREADY_USED, INVALID }

    /** Son kabul edilen süreli denemenin gün sayısı; arayüz mesajı için. */
    var lastTrialDays = 0
        private set

    fun redeem(code: String, playerId: String, onResult: (RedeemResult) -> Unit) {
        val normalized = normalizeCode(code)
        if (normalized.isEmpty()) { onResult(RedeemResult.INVALID); return }

        // SÜRELİ deneme en başta sınanıyor: kalıcı listeye de yazılmış olsaydı
        // oyuncu süresiz premium alırdı. Liste de aynı sadeleştirmeden
        // geçiriliyor — iki taraf aynı kurala uymazsa hiçbir kod tutmaz.
        TRIAL_PROMO_CODES.entries.firstOrNull {
            normalizeCode(it.key) == normalized
        }?.value?.let { days ->
            // trialUntil geçmişte bile olsa hak harcanmış sayılır
            if (trialUntil > 0L) { onResult(RedeemResult.TRIAL_ALREADY_USED); return }
            grantTrial(days)
            onResult(RedeemResult.TRIAL)
            return
        }

        if (PROMO_CODES.any { normalizeCode(it) == normalized }) {
            grantPromo()
            onResult(RedeemResult.PREMIUM)
            return
        }
        PromoCodes.redeem(normalized, playerId) { accepted ->
            if (accepted) grantPromo()
            onResult(if (accepted) RedeemResult.PREMIUM else RedeemResult.INVALID)
        }
    }

    private fun grantTrial(days: Int) {
        trialUntil = System.currentTimeMillis() + days * 86_400_000L
        lastTrialDays = days
        p.edit().putLong(KEY_TRIAL_UNTIL, trialUntil).apply()
        recomputePremium()
    }

    private fun grantPromo() {
        promoGranted = true
        p.edit().putBoolean("store.promo", true).apply()
        recomputePremium()
    }

    /**
     * Yanlış kod girildiğinde çağrılır. Eşiği aşan İLK denemede (bir kereye
     * mahsus) true döner — arayüz bu durumda teselli yıldızlarını verir.
     */
    fun recordFailedPromoAttempt(): Boolean {
        promoFailCount++
        p.edit().putInt("store.promoFailCount", promoFailCount).apply()
        if (promoFailCount <= PROMO_FAIL_BONUS_THRESHOLD || promoBonusGranted) return false
        promoBonusGranted = true
        p.edit().putBoolean("store.promoBonusGranted", true).apply()
        return true
    }

    /** premium = gerçek satın alma VEYA tanıdık kodu */
    /** premium = satın alma VEYA tanıdık kodu VEYA bahşiş VEYA yıldız eşiği */
    private fun recomputePremium() {
        isPremium = entitled || promoGranted || isSupporter || starGranted || trialActive
        p.edit().putBoolean("store.premiumCache", entitled).apply()
    }

    /** Süreli deneme şu anda işliyor mu? */
    val trialActive: Boolean get() = trialUntil > System.currentTimeMillis()

    /**
     * Denemenin bitmesine kaç gün kaldı. İşlemiyorsa null.
     * Yukarı yuvarlanıyor: son günün ortasındaki oyuncuya "0 gün kaldı"
     * demek, hakkı varken bitmiş gibi göstermek olurdu.
     */
    val trialDaysLeft: Int?
        get() {
            val ms = trialUntil - System.currentTimeMillis()
            if (ms <= 0) return null
            return maxOf(1, Math.ceil(ms / 86_400_000.0).toInt())
        }

    /**
     * Süreli denemenin bitip bitmediğini yeniden değerlendirir.
     * Oyun açıkken süre dolabiliyor; uygulama öne geldiğinde çağrılıyor.
     */
    fun refreshTrialState() {
        val shouldBe = entitled || promoGranted || isSupporter || starGranted || trialActive
        if (isPremium != shouldBe) recomputePremium()
    }

    // MARK: Yıldızla premium

    /**
     * Yıldız sayısı değiştiğinde çağrılır. Eşik geçildiyse premium kalıcı
     * veriliyor ve `true` dönüyor (kutlama kartı buna bakıyor).
     *
     * Yıldız HARCANMIYOR. Küreler de eşikle açılıyor; harcama olsaydı
     * premium'u alan oyuncu henüz açılmamış kürelerini geri kaybederdi,
     * yani ödül cezaya dönerdi.
     */
    fun checkStarUnlock(totalStars: Int): Boolean {
        if (starGranted || totalStars < STAR_PREMIUM_THRESHOLD) return false
        // Zaten premium'u olana kutlama ÇIKMIYOR: söylenecek yeni bir şey yok.
        // Hak yine de işaretleniyor — satın alması bir gün iade edilse bile
        // emeğiyle kazandığı yerinde kalsın.
        val announce = !isPremium
        starGranted = true
        p.edit().putBoolean("store.starPremium", true).apply()
        recomputePremium()
        if (announce) thankYou = ThankYou(ThankYou.Kind.STARS)
        return announce
    }

    /** Eşiğe ne kadar kaldı — teklif ekranındaki çubuk bunu gösteriyor */
    fun starProgress(totalStars: Int): Float =
        (totalStars.toFloat() / STAR_PREMIUM_THRESHOLD).coerceAtMost(1f)

    // MARK: Fiyat sabit kaldı rozeti
    //
    // Bu güncellemeyle gelen her şey (yeni bölüm çeşitleri, yeni küreler,
    // kendi kaydettiğin sesler, sonsuz modda canlar) fiyata dokunmadan geldi.
    // Söylenmeye değer ve DOĞRU olan cümle bu: "fiyat artmadı". Metinde sürüm
    // numarası GEÇMİYOR — bir sonraki sürümde yalan olmasın diye.
    //
    // Rozetin BİTİŞ TARİHİ var. "Bu ay" diyen bir söz kodda da bir ay
    // sürmeli; tarihsiz bırakılırsa yarın yalan olur. Süre dolunca rozet
    // kendiliğinden kayboluyor, elle kaldırmak gerekmiyor. Tarih iOS'takiyle
    // aynı: iki mağazada aynı gün bitiyor.
    val isPriceHoldActive: Boolean
        get() {
            val end = Calendar.getInstance().apply {
                clear()
                set(PRICE_HOLD_END_YEAR, PRICE_HOLD_END_MONTH, PRICE_HOLD_END_DAY)
            }
            return System.currentTimeMillis() < end.timeInMillis
        }

    // MARK: Destekçi kaydı
    //
    // Kim ne aldı bilinsin ki sonradan hediye premium/kod gönderilebilsin.
    // Kayıt Firestore'daki `supporters` koleksiyonuna gider; kurallar okumayı
    // istemciye KAPATIR, yalnızca konsoldan görünür.

    private fun record(productId: String) {
        val price = products.firstOrNull { it.productId == productId }
            ?.oneTimePurchaseOfferDetails?.formattedPrice ?: ""
        Supporters.record(
            playerId = p.getString("player.id", null) ?: "anonymous",
            username = p.getString("player.username", null) ?: "",
            productId = productId,
            price = price
        )
    }
}
