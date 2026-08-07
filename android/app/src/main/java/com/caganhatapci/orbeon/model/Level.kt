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
    val isGate: Boolean = false
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
    val dwellLimit: Double? = null    // bu süre dolunca küre kendiliğinden fırlar
) {
    val startRing: Int get() = 0
    val bonusDuration: Double get() = 25.0

    /** Bu bölümden alınabilecek azami yıldız (lumen değerlerinin toplamı). */
    val maxStars: Int get() = lumens.sumOf { it.value }

    /** Kapı yalnızca her şey toplandığında açılır mı? */
    val gateNeedsAllLumens: Boolean get() = kind == LevelKind.COLLECT

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
    const val COUNT = 150
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

    fun isBonus(id: Int): Boolean = id > 0 && id % 6 == 0

    /** Kapı tüm lumenler toplanana kadar açılmaz; ölünce bölüm baştan. */
    fun isCollect(id: Int): Boolean {
        if (id <= LEGACY_COUNT || isBonus(id)) return false
        return id % 3 == 1
    }

    /** "Büyük yıldız": 3 küçük lumen yerine 4 eden tek bir iri lumen. */
    fun hasGrandStar(id: Int): Boolean {
        if (id <= LEGACY_COUNT || isBonus(id)) return false
        return id % 3 == 2
    }

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
        val d = difficulty(id)
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

        // Topla-bitir bölümlerinde süre baskısı yok: asıl meydan okuma kapıyı
        // açmak için haritayı süpürmek. İkisi üst üste binerse ceza olur.
        val collect = isCollect(id)
        return Level(
            id,
            if (collect) LevelKind.COLLECT else LevelKind.NORMAL,
            rings,
            lumens,
            if (collect) null else timeLimit,
            if (collect) null else dwellLimit(id)
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
        return when {
            n <= 2 -> Difficulty(   // öğretici — ama uyutmayan
                5, 0.088f, 0.105f, 1.9f, 2.3f, 0.26f, 0.32f,
                0f, 0f, 0f, false, 0f, 0f
            )
            n <= 5 -> Difficulty(   // tehlikeler hemen başlar, dönerek
                6, 0.08f, 0.10f, 2.3f, 2.9f, 0.25f, 0.33f,
                0.52f, (PI * 0.20).toFloat(), (PI * 0.36).toFloat(), true, 0.15f, 0.07f
            )
            n <= 10 -> Difficulty(
                7, 0.075f, 0.095f, 2.8f, 3.4f, 0.24f, 0.34f,
                0.62f, (PI * 0.26).toFloat(), (PI * 0.44).toFloat(), true, 0.3f, 0.09f
            )
            n <= 18 -> Difficulty(
                7, 0.07f, 0.09f, 3.1f, 3.8f, 0.23f, 0.34f,
                0.70f, (PI * 0.30).toFloat(), (PI * 0.50).toFloat(), true, 0.5f, 0.11f
            )
            n <= 28 -> Difficulty(
                8, 0.065f, 0.085f, 3.3f, 4.2f, 0.22f, 0.35f,
                0.80f, (PI * 0.32).toFloat(), (PI * 0.55).toFloat(), true, 0.62f, 0.12f
            )
            else -> {               // ustalık — sona doğru sertleşir
                val ringCount = (9 + (max(0f, t - 0.28f) * 5.8f).toInt()).coerceIn(9, 13)
                Difficulty(
                    ringCount,
                    0.048f - 0.008f * t, 0.078f - 0.014f * t,
                    3.5f + 1.0f * t, 4.3f + 1.7f * t,
                    0.20f, 0.33f,
                    min(0.86f + 0.11f * t, 0.97f),
                    (PI * 0.34).toFloat(), (PI * (0.62 + 0.22 * t)).toFloat(), true,
                    min(0.7f + 0.25f * t, 0.92f), 0.13f + 0.03f * t
                )
            }
        }
    }
}
