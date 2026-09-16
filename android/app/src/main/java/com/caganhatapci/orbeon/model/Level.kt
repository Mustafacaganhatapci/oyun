package com.caganhatapci.orbeon.model

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

// Bölüm tanımları. Tüm koordinatlar normalize uzaydadır: x ∈ [0,1] ekran
// genişliği, y ∈ [0,1] oynanabilir alan yüksekliği (0 = alt). Yarıçaplar
// genişlik oranıdır. iOS sürümüyle birebir aynı sayıları üretir.

data class Pt(val x: Float, val y: Float)

enum class Axis { HORIZONTAL, VERTICAL }

data class MovingSpec(
    val axis: Axis,
    val amplitude: Float,   // normalize
    val period: Float,      // saniye
    val phase: Float        // radyan
)

data class ArcRange(val start: Float, val end: Float)

data class RingSpec(
    val center: Pt,
    val radius: Float,
    val orbitSpeed: Float,          // radyan/sn
    val direction: Float,           // 1 = saat yönünün tersi, -1 = saat yönü
    val hazardArcs: List<ArcRange> = emptyList(),
    val hazardRotationSpeed: Float = 0f,
    val moving: MovingSpec? = null,
    val isGate: Boolean = false,
    /** KAÇIŞ kapısı — zincirin dışında duran ikinci kapı. Beyaz çiziliyor,
     *  bölümü hemen bitiriyor, arkasındaki yıldızlar orada kalıyor. */
    val isShortcutGate: Boolean = false
)

data class LumenSpec(
    val position: Pt,
    /** Kaç yıldız değerinde. Normal lumen 1; "büyük yıldız" 4 eder. */
    val value: Int = 1
) {
    val isGrand: Boolean get() = value > 1
}

enum class LevelKind {
    NORMAL,
    BONUS,
    /** Kapı tüm lumenler toplanana kadar kilitli; ölünce bölüm baştan başlar. */
    COLLECT
}

data class Level(
    val id: Int,
    val kind: LevelKind,
    val rings: List<RingSpec>,
    val lumens: List<LumenSpec>,
    val timeLimit: Double? = null,    // süreli bölüm: kapıya bu sürede ulaş
    val dwellLimit: Double? = null,   // bu süre dolunca küre kendiliğinden fırlar
    /** RENKLER TERS: halka kırmızı, öldüren yay BEYAZ. */
    val invertedHazard: Boolean = false,
    /** Baş aşağı: küre yukarıda başlıyor, kapı aşağıda. */
    val upsideDown: Boolean = false,
    /** Zincirin yanında ikinci, beyaz bir kapı var. */
    val hasShortcutGate: Boolean = false
) {
    val startRing: Int get() = 0
    val bonusDuration: Double get() = 25.0

    /** Bu bölümden alınabilecek azami yıldız (lumen değerlerinin toplamı). */
    val maxStars: Int get() = lumens.sumOf { it.value }

    /** Kapı yalnızca her şey toplandığında açılır mı? */
    val gateNeedsAllLumens: Boolean get() = kind == LevelKind.COLLECT

    /**
     * Kapı EN AZ BİR yıldız toplanmadan açılmaz.
     *
     * Yıldızlar başından beri isteğe bağlıydı: hattı takip etmeden doğrudan
     * kapıya gidip bölümü geçmek mümkündü ve oyuncular tam da bunu yapıyordu.
     * Bölüm o zaman "üç halka atla" oluyor, tasarlanan yol hiç görülmüyordu.
     *
     * Bir tanesi kasıtlı olarak az: amaç zorlaştırmak değil, oyuncuyu hattın
     * üstüne bir kez çekmek. Üçünü birden şart koşmak her bölümü topla-bitir
     * bölümüne çevirirdi ve o türün ayrı bir tür olmasının anlamı kalmazdı.
     *
     * ÖĞRETİCİ DE DÂHİL. Bir ara dışarıda bırakılmıştı — "orada kural sırayla
     * öğretiliyor" diye. Tam tersiydi: öğretici, kuralın öğretilmesi gereken
     * YER. Muaf tutulunca oyuncu antrenmanı "kapıya git" diye bitiriyor, sonra
     * 1. bölümde kilitli bir kapıyla karşılaşıyor ve kimse ona sebebini
     * söylememiş oluyordu.
     *
     * Öğreticinin üç yıldızından ikisi zaten uçuş hattının üstünde duruyor,
     * yani kural burada oyuncuyu neredeyse hiç durdurmuyor — yalnızca
     * öğretiyor.
     */
    val gateNeedsAnyLumen: Boolean
        get() = kind == LevelKind.NORMAL &&
            lumens.isNotEmpty() && !gateNeedsAllLumens

    /** Ölünce son halkaya değil, bölümün başına dönülür; lumenler geri gelir. */
    val restartsOnDeath: Boolean get() = kind == LevelKind.COLLECT
}

/**
 * Deterministik RNG — bölümler her cihazda birebir aynı olsun diye.
 * iOS'taki SplitMix64 ile aynı diziyi üretir.
 */
class SplitMix64(seed: Long) {
    private var state: Long = seed

    fun next(): Long {
        state += -0x61c8864680b583ebL          // 0x9E3779B97F4A7C15
        var z = state
        z = (z xor (z ushr 30)) * -0x40a7b892e31b1a47L   // 0xBF58476D1CE4E5B9
        z = (z xor (z ushr 27)) * -0x6b2fb644ecceee15L   // 0x94D049BB133111EB
        return z xor (z ushr 31)
    }

    /** [0,1) aralığında düzgün dağılımlı değer */
    private fun unit(): Float = ((next() ushr 11).toDouble() / (1L shl 53).toDouble()).toFloat()

    fun rand(from: Float, to: Float): Float = from + unit() * (to - from)

    fun <T> shuffled(list: List<T>): List<T> {
        val out = list.toMutableList()
        for (i in out.indices.reversed()) {
            if (i == 0) break
            val j = (unit() * (i + 1)).toInt().coerceIn(0, i)
            val tmp = out[i]; out[i] = out[j]; out[j] = tmp
        }
        return out
    }
}

data class Difficulty(
    val ringCount: Int,
    val radiusFrom: Float, val radiusTo: Float,
    val speedFrom: Float, val speedTo: Float,
    val gapFrom: Float, val gapTo: Float,
    val hazardChance: Float,
    val hazardSpanFrom: Float, val hazardSpanTo: Float,
    val hazardsRotate: Boolean,
    val movingChance: Float,
    val movingAmplitude: Float
)

object LevelLibrary {
    const val COUNT = 257
    const val AD_FREE_LEVELS = 10        // ilk 10 bölümde asla reklam yok
    const val TUTORIAL_ID = 0

    /**
     * Kampanya 120'den 150'ye çıkarıldığında 1...120'nin AYNEN aynı kalması
     * gerekiyordu: kayıtlı ilerleme bu bölümlerin düzenine göre kazanılmış.
     * Zorluk eğrisi bölüm sayısına bölünerek hesaplandığı için payda burada
     * eski değere (120 bölümde 100 normal bölüm) sabitlenir.
     */
    const val LEGACY_COUNT = 120
    private const val CURVE_NORMAL_COUNT = LEGACY_COUNT - LEGACY_COUNT / 6   // 100

    /**
     * Kampanyanın bir önceki uzunluğu. 121...150 de artık yayında olduğu için
     * o aralık da olduğu gibi korunuyor; yeni kurallar buradan sonrası için.
     */
    const val PRIOR_COUNT = 150

    fun isBonus(id: Int): Boolean = id > 0 && id % 6 == 0

    /**
     * Yeni bölüm türleri kampanyanın ikinci yarısında başlar. 60...120
     * arasında yedide bir serpiştirilir (çeşitlilik), 120'den sonra üçte bire
     * çıkar (yeni bölümlerin kimliği bu türler).
     */
    const val KINDS_FROM = 60

    /** Kapı tüm lumenler toplanana kadar açılmaz; ölünce bölüm baştan. */
    fun isCollect(id: Int): Boolean {
        if (id < KINDS_FROM || isBonus(id)) return false
        return if (id > LEGACY_COUNT) id % 3 == 1 else id % 7 == 4
    }

    /**
     * "Büyük yıldız": 3 küçük lumen yerine 4 eden tek bir iri lumen.
     *
     * 150'den sonra seyrekliyor (üçte birden dörtte bire) ve topla-bitir
     * bölümleriyle çakışmıyor: tek lumenli bir topla-bitir bölümü, kapıyı tek
     * yıldızla açmak demek olurdu — bölüm türünün anlamı kalmazdı. Sayı
     * ayrıca kampanyanın toplamını tam 806 yıldıza oturtuyor.
     */
    fun hasGrandStar(id: Int): Boolean {
        if (id < KINDS_FROM || isBonus(id)) return false
        if (id <= LEGACY_COUNT) return id % 7 == 1
        if (id <= PRIOR_COUNT) return id % 3 == 2
        return id % 4 == 1 && !isCollect(id)
    }

    // Çeşit bölümleri — iOS'takiyle BİREBİR aynı bölenler ve eşikler.
    //
    // Üçü de bir zamanlar YALNIZCA 150'den sonra çıkıyordu; gerekçe 1...150'in
    // yayında olması ve oradaki düzenin korunmasıydı. O kaygı kasıtlı olarak
    // bırakıldı: üç çeşidin tamamı kampanyanın son beşte birine sıkışınca,
    // oyuncuların çoğu hiçbirini görmüyordu. Artık kampanyanın tamamına
    // yayılıyorlar. Kazanılmış yıldızlar ve tamamlanma kayıtları yerinde
    // duruyor — bölümün düzeni değişiyor, oyuncunun geçmişi değişmiyor.
    //
    // BAŞLANGIÇ NOKTALARI ÖĞRENME SIRASINA GÖRE:
    //   25 — baş aşağı: hiçbir kuralı değiştirmiyor, yalnızca alışkanlığı
    //   35 — iki çıkış: kapının ve yıldızın ne olduğunu bilmek yetiyor
    //   45 — ters renk: "kırmızı yakar" ezberi ÖNCE kurulmalı ki bozulabilsin
    //
    // BÖLENLER FARKLI SEÇİLDİ. Aynı bölenle iki çeşit sabit mesafede kalıyor
    // ve her seferinde yan yana düşüyordu: iki büyük sürpriz art arda, sonra
    // yedi sıradan bölüm. Şimdi hiçbir çeşit bir diğerinin komşusu değil.
    //
    // ÜÇÜ DE TOPLA-BİTİR BÖLÜMLERİNİ DIŞLIYOR. Tek bölümde iki kural olunca
    // giriş kartındaki tek satır yalan söylüyor.

    /** Renkler ters: halka kırmızı, öldüren yay beyaz. */
    fun isInverted(id: Int): Boolean {
        if (id < 45 || isBonus(id) || isCollect(id)) return false
        return id % 10 == 1
    }

    /** Baş aşağı: küre yukarıda başlar, kapı aşağıdadır. */
    fun isUpsideDown(id: Int): Boolean {
        if (id < 25 || isBonus(id) || isCollect(id) || isInverted(id)) return false
        return id % 8 == 1
    }

    /**
     * Zincirin yanında ikinci bir kapı. Topla-bitir bölümünde OLMAZ: orada
     * kapı zaten yıldızların hepsi toplanana kadar açılmıyor.
     *
     * Bölen 8: `id % 9 == 4` demek `id % 3 == 1` demek, yani 150 sonrasında
     * her seferinde topla-bitir bölümüne denk gelip eleniyordu.
     */
    fun hasShortcutGate(id: Int): Boolean {
        if (id < 35 || isBonus(id) || isCollect(id)) return false
        if (isInverted(id) || isUpsideDown(id)) return false
        return id % 12 == 3
    }

    /**
     * Zamanın yavaşladığı bölümler: küreye BASILI TUTUNCA zaman ağırlaşıyor.
     *
     * Yetenek gizli chrono küresinden geliyor ama burada küreye değil BÖLÜME
     * bağlı — hangi karakterle oynarsan oyna çalışıyor. Gizli küre yine de
     * değerini koruyor: iniş noktasını gösteren nişan çizgisi yalnızca onda,
     * ve o çizgiyi bu bölümlerde de yalnızca o taşıyor.
     *
     * Bu bölümler bilerek DAHA ZOR üretiliyor (`slowTimeBoost`): halkalar daha
     * hızlı döner, daha çok tehlike ve daha çok hareketli halka çıkar.
     * Yavaşlatma bir hediye değil, zorluğun cevabı — yoksa yetenek yalnızca
     * zaten geçilebilen bir bölümü kolaylaştıran bir düğme olurdu.
     *
     * 20'DEN SONRA başlıyor, 150'den değil. Öteki çeşitlerin aksine bu bir
     * kural değil bir YETENEK: oyuncudan bir şey istemiyor, ona bir şey
     * veriyor. Kampanyanın sonuna saklamak, on iki bölümlük bir sürprizi
     * oyuncuların çoğunun hiç görmemesi demekti. İlki 26'da; ilk yirmi bölüm
     * temel atlayışın öğrenildiği yer ve oraya yeni bir düğme koymak erken.
     *
     * Bölen 6 kampanyanın tamamına otuz bir bölüm serpiyor; aralıklar 6 ile 18
     * arasında, yani tür ne seyrekleşip unutuluyor ne de sıradanlaşıyor. Bonus
     * da altıya bölünüyor ama kalanı 0 — çakışma yok.
     *
     * Önce on iki bölümdü (bölen 11). Bir türün oyuncuda iz bırakması için
     * birkaç kez karşısına çıkması gerekiyor: on iki bölüm, iki yüz elli
     * yedilik bir kampanyada iki oturumda bir denk gelen bir şey demekti.
     * iOS'takiyle BİREBİR aynı.
     */
    fun slowsTime(id: Int): Boolean {
        if (id <= 20 || isBonus(id) || isCollect(id)) return false
        if (isInverted(id) || isUpsideDown(id) || hasShortcutGate(id)) return false
        return id % 6 == 2
    }

    /**
     * Zorluk zammı YAVAŞLATAN HER BÖLÜME — yayında olanlara da.
     *
     * Bir ara bu yalnızca 150 sonrasına uygulanıyordu: 21...150 yayındaydı ve
     * oradaki bir bölümün DÜZENİNİ değiştirmek, kuralını değiştirmekten başka
     * bir şey sayılıyordu. Ama o kaygı kasıtlı olarak bırakıldı — yavaşlatma
     * zorluğun cevabı, ve zorlaşmayan bir bölümde cevap verilecek bir şey de
     * yok: yetenek orada yalnızca zaten geçilebilen bir bölümü kolaylaştıran
     * bir düğme olurdu. On iki bölümün ikisi zor, onu kolay olamaz.
     *
     * Kazanılmış yıldızlar ve tamamlanma kayıtları YERİNDE duruyor: bölümün
     * düzeni değişiyor, oyuncunun geçmişi değişmiyor.
     * iOS'takiyle BİREBİR aynı.
     */
    fun slowTimeIsHard(id: Int): Boolean = slowsTime(id)

    /**
     * Yavaşlatan bölümün zorluk zammı. Ayrı bir fonksiyon: kuralın hangi
     * bölümde geçerli olduğu ile ne kadar zorlaştırdığı ayrı ayrı okunsun.
     *
     * TEHLİKE YOĞUNLUĞU yalnızca müsamaha varken artıyor (`HAZARD_GRACE_FROM`,
     * 67). Öncesinde yaya değmek ANINDA öldürüyor; oraya %90 tehlike olasılığı
     * koymak zor değil adaletsiz olurdu — 26. bölümdeki oyuncu henüz yayın ne
     * zaman silahlandığını okumayı öğrenmiyor bile, çünkü o mekanik daha yok.
     * Hız ve hareketli halka ise beceri zorluğu ve yavaşlatmanın doğrudan
     * cevap verdiği şey tam olarak bu; onlar her yerde artıyor.
     *
     * Katsayılar iOS'takiyle birebir aynı.
     */
    fun slowTimeBoost(d: Difficulty, graceful: Boolean): Difficulty = d.copy(
        speedFrom = d.speedFrom * 1.18f,
        speedTo = d.speedTo * 1.18f,
        hazardChance = if (graceful) minOf(0.95f, d.hazardChance + 0.15f) else d.hazardChance,
        movingChance = minOf(1f, d.movingChance + 0.20f),
        hazardSpanFrom = d.hazardSpanFrom * 1.10f,
        hazardSpanTo = d.hazardSpanTo * 1.10f
    )

    /**
     * Tehlike müsamahasının başladığı bölüm. Buradan sonra (ve sonsuz modda)
     * tehlikeli bir halkaya tutunan küre, o halka etrafında bir tam tur dönene
     * kadar yanmaz; yayın üstündeki yeşil kaplama o süre boyunca erir.
     */
    const val HAZARD_GRACE_FROM = 67

    fun hasHazardGrace(id: Int): Boolean = id >= HAZARD_GRACE_FROM

    /** Zorluk eğrisinin 0...1 konumu; 100. normal bölümden sonra 1'de durur. */
    private fun curveT(n: Int): Float =
        ((n - 1).toFloat() / max(1, CURVE_NORMAL_COUNT - 1).toFloat()).coerceIn(0f, 1f)

    /** Bölümün azami yıldızı — bölüm seçme ekranı bunu üretmeden bilmek ister. */
    fun maxStars(id: Int): Int = if (!isBonus(id) && hasGrandStar(id)) 4 else 3

    /** Kampanyadan toplanabilecek toplam yıldız (ana menüdeki "x / y") */
    val totalStarsAvailable: Int by lazy { (1..COUNT).sumOf { maxStars(it) } }

    /** İlk açılışta oynatılan "nasıl oynanır" antrenman bölümü. */
    val tutorialLevel: Level
        get() {
            val rings = listOf(
                RingSpec(Pt(0.50f, 0.15f), 0.105f, 1.3f, 1f),
                RingSpec(Pt(0.50f, 0.42f), 0.105f, 1.3f, -1f),
                RingSpec(Pt(0.50f, 0.69f), 0.105f, 1.3f, 1f, isGate = true)
            )
            val lumens = listOf(
                LumenSpec(Pt(0.50f, 0.285f)),
                LumenSpec(Pt(0.50f, 0.555f)),
                LumenSpec(Pt(0.605f, 0.42f))
            )
            return Level(TUTORIAL_ID, LevelKind.NORMAL, rings, lumens)
        }

    /** Speed Run: ilk 10 normal bölüm (bonuslar atlanır) */
    val speedrunLevels: List<Int>
        get() {
            val result = mutableListOf<Int>()
            var id = 1
            while (result.size < 10) {
                if (!isBonus(id)) result.add(id)
                id++
            }
            return result
        }

    /** id'nin kaçıncı NORMAL bölüm olduğu — zorluk eğrisi bunun üzerinden yürür */
    fun normalIndex(id: Int): Int = id - id / 6

    /** Süreli bölümler: 12. normal bölümden itibaren her 4 normal bölümde bir. */
    fun isTimed(id: Int): Boolean {
        if (isBonus(id)) return false
        val n = normalIndex(id)
        return n >= 12 && n % 4 == 0
    }

    /**
     * HUD geri sayımı göstermeli mi? `isTimed` tek başına yetmiyor:
     * topla-bitir bölümlerinde süre baskısı BİLEREK kaldırılıyor
     * (bkz. `normalLevel`), ama gösterge yine de çiziliyordu ve süresiz bir
     * bölümde 0'da donmuş bir sayaç gibi duruyordu.
     */
    fun hasTimer(id: Int): Boolean = isTimed(id) && !isCollect(id)

    /** Öğrenme bölgesi: ekrandan çıkan küre elenmek yerine halkasına döner. */
    fun isForgiving(id: Int): Boolean {
        if (id == TUTORIAL_ID || isBonus(id)) return true
        return normalIndex(id) < 11
    }

    /** "Devam et ya da düş": 15. normal bölümden itibaren oyalanma süresi. */
    fun dwellLimit(id: Int): Double? {
        if (isBonus(id) || isTimed(id)) return null
        val n = normalIndex(id)
        if (n < 15) return null
        return max(2.2, 3.6 - 1.4 * curveT(n).toDouble())
    }

    fun level(id: Int): Level {
        if (id == TUTORIAL_ID) return tutorialLevel
        return if (isBonus(id)) bonusLevel(id) else normalLevel(id)
    }

    // MARK: Normal bölüm üretimi

    private fun normalLevel(id: Int): Level {
        // Yavaşlatan bölüm daha zor üretiliyor: yetenek zorluğun cevabı olsun,
        // zaten geçilebilen bir bölümü kolaylaştıran bir düğme olmasın
        val d = if (slowTimeIsHard(id))
            slowTimeBoost(difficulty(id), hasHazardGrace(id))
        else difficulty(id)
        val rng = SplitMix64(0xC0FFEEL + id.toLong() * 7919L)

        val rings = mutableListOf<RingSpec>()
        var cursor = Pt(0.5f, 0.10f)
        rings.add(RingSpec(cursor, d.radiusFrom + 0.01f, d.speedFrom, 1f))

        cursor = buildChain(rings, cursor, rng, d)

        // 3 lumen: ardışık halka çiftlerinin arasına, uçuş hattına yakın
        val lumens = mutableListOf<LumenSpec>()
        val pairCount = rings.size - 1
        val pairIndices = rng.shuffled((0 until pairCount).toList()).take(3).sorted()
        for (p in pairIndices) {
            val a = rings[p].center
            val b = rings[p + 1].center
            val t = rng.rand(0.42f, 0.58f)
            lumens.add(LumenSpec(Pt(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)))
        }
        while (lumens.size < 3) {
            lumens.add(LumenSpec(Pt(rng.rand(0.3f, 0.7f), rng.rand(0.3f, 0.7f))))
        }

        // "Büyük yıldız" bölümü: 3 küçük lumen yerine 4 eden tek bir iri lumen.
        // Zincirin ortasındaki halka çiftinin arasına, uçuş hattının biraz
        // dışına konur — bedavaya gelmesin, sapmayı hak etsin.
        if (hasGrandStar(id)) {
            val mid = max(0, (rings.size - 1) / 2)
            val a = rings[mid].center
            val b = rings[mid + 1].center
            val off = rng.rand(0.06f, 0.10f) * (if (rng.rand(0f, 1f) < 0.5f) 1f else -1f)
            val px = ((a.x + b.x) / 2f - (b.y - a.y) * off * 2f).coerceIn(0.08f, 0.92f)
            val py = ((a.y + b.y) / 2f + (b.x - a.x) * off * 2f).coerceIn(0.06f, 0.94f)
            lumens.clear()
            lumens.add(LumenSpec(Pt(px, py), value = 4))
        }

        // Süreli bölüm: halka başına tanınan süre ilerledikçe kısalır
        var timeLimit: Double? = null
        if (isTimed(id)) {
            val t = curveT(normalIndex(id)).toDouble()
            timeLimit = Math.round(rings.size * (4.0 - 1.4 * t)).toDouble()
        }

        // Kaçış kapısı zincirin DIŞINA konuyor. Yola konsaydı üstüne basmak
        // zorunlu olurdu ve "erken çık" bir seçim değil, mecburiyet olurdu.
        // Yıldızlar yerleştikten SONRA ekleniyor: lumen konumları halka
        // çiftlerine göre hesaplanıyor, araya girmek onları kaydırırdı.
        var shortcut = false
        if (hasShortcutGate(id) && rings.size >= 5) {
            val anchor = rings[rings.size / 2].center
            val radius = 0.085f
            val margin = 0.05f
            var best: Pt? = null
            var bestScore = -Float.MAX_VALUE
            var fallback: Pt? = null
            var fallbackClear = -Float.MAX_VALUE
            var gx = 0.13f
            while (gx <= 0.87f) {
                var gy = 0.10f
                while (gy <= 0.90f) {
                    val p = Pt(gx, gy)
                    val c = clearance(p, radius, rings)
                    if (c > fallbackClear) { fallbackClear = c; fallback = p }
                    if (c >= margin) {
                        val dx = p.x - anchor.x
                        val dy = p.y - anchor.y
                        val score = -kotlin.math.abs(sqrt(dx * dx + dy * dy) - 0.26f)
                        if (score > bestScore) { bestScore = score; best = p }
                    }
                    gy += 0.03f
                }
                gx += 0.03f
            }
            // Sıkışık haritada en ferah nokta yine de alınıyor: harita "iki
            // çıkış var" diye rozet taşıyorsa ikinci kapı MUTLAKA konmalı.
            val spot = best ?: fallback
            if (spot != null) {
                rings.add(RingSpec(spot, radius, 1.6f, 1f,
                                   isGate = true, isShortcutGate = true))
                shortcut = true
            }
        }

        // Baş aşağı: her şey dikeyde aynalanıyor. Zincir aynı zincir; yalnızca
        // başlangıç yukarıda, kapı aşağıda kalıyor.
        val flipped = isUpsideDown(id)
        if (flipped) {
            for (i in rings.indices) {
                rings[i] = rings[i].copy(center = Pt(rings[i].center.x, 1f - rings[i].center.y))
            }
            for (i in lumens.indices) {
                lumens[i] = lumens[i].copy(
                    position = Pt(lumens[i].position.x, 1f - lumens[i].position.y))
            }
        }

        // Topla-bitir bölümlerinde süre baskısı yok: asıl meydan okuma kapıyı
        // açmak için haritayı süpürmek. İkisi üst üste binerse ceza olur.
        val collect = isCollect(id)
        return Level(
            id,
            if (collect) LevelKind.COLLECT else LevelKind.NORMAL,
            rings,
            lumens,
            if (collect) null else timeLimit,
            if (collect) null else dwellLimit(id),
            invertedHazard = isInverted(id),
            upsideDown = flipped,
            hasShortcutGate = shortcut
        )
    }

    // MARK: Bonus turu — tehlike yok, bol lumen, süre sınırlı

    private fun bonusLevel(id: Int): Level {
        val rng = SplitMix64(0xB0B0L + id.toLong() * 104729L)
        val d = Difficulty(
            ringCount = 6,
            radiusFrom = 0.085f, radiusTo = 0.105f,
            speedFrom = 2.1f, speedTo = 2.7f,
            gapFrom = 0.24f, gapTo = 0.32f,
            hazardChance = 0f, hazardSpanFrom = 0f, hazardSpanTo = 0f, hazardsRotate = false,
            movingChance = 0f, movingAmplitude = 0f
        )

        val rings = mutableListOf<RingSpec>()
        var cursor = Pt(0.5f, 0.10f)
        rings.add(RingSpec(cursor, 0.095f, 2.2f, 1f))
        cursor = buildChain(rings, cursor, rng, d)
        // Bonusta kapı yok; tur süreyle biter
        rings[rings.size - 1] = rings[rings.size - 1].copy(isGate = false)

        val lumens = mutableListOf<LumenSpec>()
        for (p in 0 until rings.size - 1) {
            val a = rings[p].center
            val b = rings[p + 1].center
            val t = rng.rand(0.40f, 0.60f)
            lumens.add(LumenSpec(Pt(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)))
        }
        while (lumens.size < 9) {
            val ring = rings[Math.round(rng.rand(0f, (rings.size - 1).toFloat())).coerceIn(0, rings.size - 1)]
            val angle = rng.rand(0f, (2 * PI).toFloat())
            val dist = ring.radius + rng.rand(0.035f, 0.06f)
            val px = (ring.center.x + cos(angle) * dist).coerceIn(0.08f, 0.92f)
            val py = (ring.center.y + sin(angle) * dist).coerceIn(0.05f, 0.95f)
            lumens.add(LumenSpec(Pt(px, py)))
        }

        return Level(id, LevelKind.BONUS, rings, lumens)
    }

    // MARK: Ortak zincir kurucu

    private fun buildChain(
        rings: MutableList<RingSpec>,
        startCursor: Pt,
        rng: SplitMix64,
        d: Difficulty
    ): Pt {
        val margin = 0.05f   // halkalar arası asgari boşluk
        var cursor = startCursor

        for (i in 1 until d.ringCount) {
            val markGate = (i == d.ringCount - 1)
            val radius = rng.rand(d.radiusFrom, d.radiusTo)

            var candidate = Pt(0.5f, 0.5f)
            var bestClearance = -Float.MAX_VALUE
            var attempts = 0
            do {
                val angle = rng.rand((PI * 0.22).toFloat(), (PI * 0.78).toFloat())
                val dist = rng.rand(d.gapFrom, d.gapTo)
                val px = (cursor.x + cos(angle) * dist * 0.9f).coerceIn(0.15f, 0.85f)
                val py = (cursor.y + sin(angle) * dist).coerceIn(0.08f, 0.92f)
                val p = Pt(px, py)
                val c = clearance(p, radius, rings)
                if (c > bestClearance) { bestClearance = c; candidate = p }
                attempts++
            } while (bestClearance < margin && attempts < 40)

            if (bestClearance < margin) {
                var bestScore = -Float.MAX_VALUE
                var gx = 0.15f
                while (gx <= 0.85f) {
                    var gy = 0.08f
                    while (gy <= 0.92f) {
                        val p = Pt(gx, gy)
                        if (clearance(p, radius, rings) >= margin) {
                            val dx = p.x - cursor.x
                            val dy = p.y - cursor.y
                            val score = -kotlin.math.abs(sqrt(dx * dx + dy * dy) - 0.30f)
                            if (score > bestScore) { bestScore = score; candidate = p }
                        }
                        gy += 0.04f
                    }
                    gx += 0.04f
                }
            }

            val dir = if (rng.rand(0f, 1f) < 0.5f) 1f else -1f
            var hazardArcs: List<ArcRange> = emptyList()
            var hazardRotation = 0f
            var moving: MovingSpec? = null

            // Tehlike yayları — kapıya ve ilk iki halkaya asla koyma
            if (!markGate && i > 1 && rng.rand(0f, 1f) < d.hazardChance) {
                val span = rng.rand(d.hazardSpanFrom, d.hazardSpanTo)
                val start = rng.rand(0f, (2 * PI).toFloat())
                hazardArcs = listOf(ArcRange(start, start + span))
                if (d.hazardsRotate) {
                    hazardRotation = rng.rand(0.4f, 1.0f) * (if (rng.rand(0f, 1f) < 0.5f) 1f else -1f)
                }
            }

            // Hareketli halkalar — genlik komşulara çarpmayacak kadar kırpılır
            if (!markGate && i > 1 && rng.rand(0f, 1f) < d.movingChance) {
                val clear = clearance(candidate, radius, rings)
                val amplitude = min(
                    rng.rand(0.05f, max(0.051f, d.movingAmplitude)),
                    max(0.03f, clear - 0.02f)
                )
                moving = MovingSpec(
                    axis = if (rng.rand(0f, 1f) < 0.6f) Axis.HORIZONTAL else Axis.VERTICAL,
                    amplitude = amplitude,
                    period = rng.rand(2.2f, 4.0f),
                    phase = rng.rand(0f, (2 * PI).toFloat())
                )
            }

            rings.add(
                RingSpec(
                    center = candidate,
                    radius = radius,
                    orbitSpeed = rng.rand(d.speedFrom, d.speedTo),
                    direction = dir,
                    hazardArcs = hazardArcs,
                    hazardRotationSpeed = hazardRotation,
                    moving = moving,
                    isGate = markGate
                )
            )
            cursor = candidate
        }
        return cursor
    }

    /** Adayın mevcut halkalara olan en dar boşluğu (negatifse örtüşüyor) */
    private fun clearance(center: Pt, radius: Float, rings: List<RingSpec>): Float {
        var minClearance = Float.MAX_VALUE
        for (r in rings) {
            val dx = r.center.x - center.x
            val dy = r.center.y - center.y
            minClearance = min(minClearance, sqrt(dx * dx + dy * dy) - (r.radius + radius))
        }
        return minClearance
    }

    // MARK: Zorluk eğrisi

    fun difficulty(id: Int): Difficulty {
        val n = normalIndex(id)
        val t = curveT(n)   // 0...1, 100. normal bölümde doyar
        // 100. normal bölümden SONRAKİ ikinci yükseliş. n <= 100 iken sıfırdır,
        // yani 1...120 arası bölümlere hiç dokunmaz.
        val t2 = ((n - CURVE_NORMAL_COUNT).toFloat() / 25f).coerceIn(0f, 1f)
        return when {
            n <= 2 -> Difficulty(   // öğretici — ama uyutmayan
                5, 0.088f, 0.105f, 1.9f, 2.3f, 0.26f, 0.32f,
                0f, 0f, 0f, false, 0f, 0f
            )
            n <= 5 -> Difficulty(   // tehlikeler hemen başlar, dönerek
                6, 0.078f, 0.098f, 2.5f, 3.1f, 0.25f, 0.33f,
                0.52f, (PI * 0.22).toFloat(), (PI * 0.38).toFloat(), true, 0.15f, 0.07f
            )
            n <= 10 -> Difficulty(
                7, 0.072f, 0.092f, 2.8f, 3.4f, 0.24f, 0.34f,
                0.62f, (PI * 0.26).toFloat(), (PI * 0.46).toFloat(), true, 0.35f, 0.09f
            )
            n <= 18 -> Difficulty(
                7, 0.067f, 0.087f, 3.1f, 3.8f, 0.23f, 0.34f,
                0.70f, (PI * 0.30).toFloat(), (PI * 0.52).toFloat(), true, 0.5f, 0.11f
            )
            n <= 28 -> Difficulty(
                8, 0.062f, 0.082f, 3.3f, 4.2f, 0.22f, 0.35f,
                0.80f, (PI * 0.32).toFloat(), (PI * 0.56).toFloat(), true, 0.62f, 0.12f
            )
            else -> {               // ustalık — sona doğru sertleşir
                val ringCount = (9 + (max(0f, t - 0.28f) * 6.4f).toInt()).coerceIn(9, 13) +
                    Math.round(t2 * 2f)
                Difficulty(
                    ringCount,
                    0.048f - 0.008f * t - 0.005f * t2, 0.078f - 0.014f * t - 0.008f * t2,
                    3.5f + 1.0f * t + 0.5f * t2, 4.3f + 1.8f * t + 0.9f * t2,
                    0.20f, 0.33f,
                    min(0.85f + 0.13f * t, 0.97f),
                    (PI * 0.34).toFloat(), (PI * (0.64 + 0.22 * t + 0.12 * t2)).toFloat(), true,
                    min(min(0.7f + 0.28f * t, 0.92f) + 0.05f * t2, 0.97f),
                    0.13f + 0.03f * t + 0.02f * t2
                )
            }
        }
    }
}
