package com.caganhatapci.orbeon.game

import com.caganhatapci.orbeon.model.ArcRange
import com.caganhatapci.orbeon.model.Axis
import com.caganhatapci.orbeon.model.Level
import com.caganhatapci.orbeon.model.LevelKind
import com.caganhatapci.orbeon.model.LevelLibrary
import com.caganhatapci.orbeon.model.LumenSpec
import com.caganhatapci.orbeon.model.Pt
import com.caganhatapci.orbeon.model.RingSpec
import com.caganhatapci.orbeon.model.SplitMix64
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

sealed class GameEvent {
    data class Hop(val combo: Int) : GameEvent()
    data class Attached(val hasHazard: Boolean, val isMoving: Boolean) : GameEvent()
    data class Collect(val total: Int) : GameEvent()
    /** Topla-bitir: son lumen toplandı, kapı açıldı */
    data object GateUnlocked : GameEvent()
    data object Fail : GameEvent()
    data class Win(val stars: Int) : GameEvent()
    data class BonusTick(val remaining: Int) : GameEvent()
    data class TimeTick(val remaining: Int) : GameEvent()
    data class EndlessScore(val score: Int) : GameEvent()
    data class EndlessGameOver(val score: Int) : GameEvent()
    /** Premium ekstra canı harcandı — HUD göstergesi güncellensin */
    data class ExtraLifeUsed(val remaining: Int) : GameEvent()
}

sealed class GameMode {
    data class LevelMode(val id: Int) : GameMode()
    data object Endless : GameMode()
}

/**
 * Tek dokunuşla oynanan yörünge oyununun simülasyonu.
 *
 * Fizik motoru kullanılmaz; hareket deterministik matematiktir — his her
 * cihazda aynıdır. Çizim bu sınıfın dışındadır: motor yalnızca durumu tutar,
 * `GameCanvas` onu okuyup çizer. Böylece oynanış render'dan bağımsız kalır.
 */
class GameEngine(
    val mode: GameMode,
    var onEvent: ((GameEvent) -> Unit)? = null,
    /** Premium oyuncuya sonsuz modda tur başına bir can (reklam izlemiyorlar) */
    isPremium: Boolean = false,
    /**
     * Hız turunda kapı, yıldızların hepsi toplanmadan açılmaz — sıralamayı
     * yıldızları atlayarak kısaltmak mümkün olmasın diye.
     */
    private val requiresAllLumens: Boolean = false
) {
    // MARK: Ayar sabitleri — iOS ile aynı (puntolar yoğunlukla ölçeklenir)
    private val flightSpeedFactor = 1.55f   // ekran genişliği / sn
    private val maxFlightTime = 4.0
    private val respawnDelay = 0.55

    /** Ekran yoğunluğu — iOS "punto" değerlerini gerçek piksele çevirir */
    var density = 1f
        private set
    val orbRadiusPx get() = 9f * density
    private val collectDistance get() = 26f * density

    sealed class OrbState {
        data class Attached(val ring: Int, val angle: Float, val direction: Float) : OrbState()
        data class Flying(val vx: Float, val vy: Float) : OrbState()
        data object Dead : OrbState()
        data object Won : OrbState()
    }

    // Ekran boyutu (piksel) — Compose ölçtüğünde atanır
    var width = 0f
        private set
    var height = 0f
        private set

    /** Öğretici dondurması: true iken simülasyon ve girdi durur. */
    var coachFrozen = false

    var level: Level? = null
        private set
    var ringSpecs: List<RingSpec> = emptyList()
        private set
    var lumens: List<Pt> = emptyList()
        private set
    var lumenCollected: BooleanArray = BooleanArray(0)
        private set
    /** Her lumenin yıldız değeri — normal 1, "büyük yıldız" 4 */
    var lumenValues: IntArray = IntArray(0)
        private set

    var orbState: OrbState = OrbState.Dead
        private set
    var orbX = 0f
        private set
    var orbY = 0f
        private set
    var orbVisible = true
        private set

    var elapsed = 0.0
        private set
    var combo = 0
        private set

    private var lastRing = 0
    private var exitedLastRing = true
    private var flightTime = 0.0
    private var deadSince: Double? = null
    private var endlessOverSent = false
    private var finished = false

    // Bonus turu
    private var isBonus = false
    private var bonusDeadline = 0.0
    private var lastBonusTick = Int.MAX_VALUE

    // Süreli bölüm — süre deneme başınadır
    private var timedDeadline: Double? = null
    private var lastTimeTickSent = Int.MAX_VALUE

    // Bağışlayıcı sınırlar
    private var forgivingBounds = false

    // Topla-bitir bölümü
    private var gateNeedsAllLumens = false
    private var restartsOnDeath = false
    private var lumenSpecs: List<LumenSpec> = emptyList()
    /** Kilitli kapı sönük çizilsin diye tuvalin okuduğu bayrak */
    val gateLocked: Boolean get() = gateNeedsAllLumens && !gateOpen

    // Tehlike müsamahası — ilk tam tur yakmaz
    private var hazardGraceEnabled = false
    private var hazardGraceUntil: Double? = null
    private val hazardGraceActive: Boolean
        get() = hazardGraceUntil?.let { elapsed < it } ?: false

    /**
     * Tuval bu bayrağa bakarak müsamaha turundaki yayı yarı saydam kırmızının
     * üstüne mor kesiklerle çizer: yay hâlâ "tehlike" gibi durur ama oyuncu
     * atlamadan da o turda yakmayacağını görebilir.
     */
    val hazardSafeRing: Int?
        get() = if (hazardGraceActive) (orbState as? OrbState.Attached)?.ring else null

    // "Devam et ya da düş"
    private var dwellLimit: Double? = null
    private var dwellStart = 0.0
    /** Aktif halkada kalan oyalanma süresi oranı (1 = dolu, 0 = bitti) */
    var dwellFraction = 1f
        private set
    var dwellVisible = false
        private set

    // Sonsuz mod
    var endlessScore = 0
        private set
    /** Kalan ekstra can — HUD sağ üstte kalp olarak gösterir */
    var extraLives = if (mode is GameMode.Endless && isPremium) 1 else 0
        private set
    var cameraY = 0f
        private set
    private val endlessRNG = SplitMix64(System.currentTimeMillis())

    /** Patlama efektleri — çizim katmanı bunları okur */
    val bursts = mutableListOf<Burst>()

    enum class FxColor { ACCENT, LUMEN, HAZARD, GATE, ORB }

    data class Burst(
        val x: Float, val y: Float,
        val color: FxColor,
        val count: Int,
        var age: Float = 0f   // negatif başlarsa gecikmeli patlar (kutlama şelalesi)
    )

    /** Kürenin izi: son konumlar yaş bilgisiyle tutulur, tuval soldurarak çizer */
    data class TrailPoint(val x: Float, val y: Float, var age: Float = 0f)
    val trail = ArrayDeque<TrailPoint>()

    /** Ölümde kısa ekran sarsıntısı — tuval bu değeri offset olarak kullanır */
    var shakeTime = 0f
        private set

    /** Öğretici dokunuş ipucu: ilk fırlatmaya kadar görünür */
    var tapHintVisible = false
        private set

    val isTutorial: Boolean
        get() = mode is GameMode.LevelMode && mode.id == LevelLibrary.TUTORIAL_ID

    val lumenTotal: Int get() = lumens.size

    // Oynanabilir alan (HUD boşlukları) — iOS'taki playRect ile aynı oran
    private val playLeft get() = 0f
    private val playBottom get() = 40f
    private val playWidth get() = width
    private val playHeight get() = height - 150f

    // MARK: Kurulum

    fun resize(w: Float, h: Float, screenDensity: Float = 1f) {
        val first = width == 0f
        width = w
        height = h
        density = screenDensity
        if (first) start()
    }

    private fun start() {
        when (mode) {
            is GameMode.LevelMode -> {
                val lvl = LevelLibrary.level(mode.id)
                level = lvl
                isBonus = lvl.kind == LevelKind.BONUS
                dwellLimit = lvl.dwellLimit
                forgivingBounds = LevelLibrary.isForgiving(mode.id)
                hazardGraceEnabled = LevelLibrary.hasHazardGrace(mode.id)
                gateNeedsAllLumens = lvl.gateNeedsAllLumens ||
                    (requiresAllLumens && lvl.lumens.isNotEmpty())
                restartsOnDeath = lvl.restartsOnDeath
                lumenSpecs = lvl.lumens
                if (isBonus) bonusDeadline = lvl.bonusDuration
                if (isTutorial) tapHintVisible = true
                ringSpecs = lvl.rings
                lumens = lvl.lumens.map { it.position }
                lumenCollected = BooleanArray(lumens.size)
                lumenValues = lvl.lumens.map { it.value }.toIntArray()
                respawn()
            }
            GameMode.Endless -> {
                hazardGraceEnabled = true
                seedEndless()
                lumens = emptyList()
                lumenCollected = BooleanArray(0)
                lumenValues = IntArray(0)
                cameraY = height / 2f
                respawn()
            }
        }
    }

    // MARK: Koordinat yardımcıları

    private fun scenePoint(p: Pt): Pair<Float, Float> =
        Pair(p.x * playWidth + playLeft,
             height - (p.y * playHeight + playBottom))

    fun ringCenter(i: Int, t: Double = elapsed): Pair<Float, Float> {
        val spec = ringSpecs[i]
        var (cx, cy) = scenePoint(spec.center)
        spec.moving?.let { m ->
            val offset = sin(t.toFloat() * 2f * PI.toFloat() / m.period + m.phase) * m.amplitude * width
            when (m.axis) {
                Axis.HORIZONTAL -> cx += offset
                Axis.VERTICAL -> cy += offset
            }
        }
        return Pair(cx, cy)
    }

    fun ringRadius(i: Int): Float = ringSpecs[i].radius * width

    fun lumenPoint(i: Int): Pair<Float, Float> = scenePoint(lumens[i])

    // MARK: Girdi — tek dokunuş, tüm ekran

    /**
     * Küreyi halkadan teğet yönünde fırlatır. Hem dokunuşla hem de oyalanma
     * süresi dolduğunda (otomatik fırlatma) buradan geçilir.
     */
    private fun launch(ring: Int, angle: Float, direction: Float) {
        val (cx, cy) = ringCenter(ring)
        val r = ringRadius(ring)
        orbX = cx + cos(angle) * r
        orbY = cy + sin(angle) * r
        val tx = -sin(angle) * direction
        val ty = cos(angle) * direction
        val speed = flightSpeedFactor * width
        orbState = OrbState.Flying(tx * speed, ty * speed)
        tapHintVisible = false
        lastRing = ring
        exitedLastRing = false
        flightTime = 0.0
    }

    fun onTap() {
        if (coachFrozen) return
        when (val s = orbState) {
            is OrbState.Attached -> launch(s.ring, s.angle, s.direction)
            OrbState.Dead -> {
                // Güvenlik ağı: yeniden doğma gecikirse dokunuş canlandırır
                val since = deadSince
                if (since != null && elapsed - since > 0.9 && mode !is GameMode.Endless) {
                    if (restartsOnDeath) restartLevel() else respawn()
                }
            }
            else -> Unit
        }
    }

    // MARK: Ana döngü

    fun update(deltaSeconds: Double) {
        if (coachFrozen) return
        if (width <= 1f) return
        val dt = min(deltaSeconds, 1.0 / 30.0)
        elapsed += dt

        // Patlama efektlerini yaşlandır (negatif yaş = henüz patlamadı)
        val it = bursts.iterator()
        while (it.hasNext()) {
            val b = it.next()
            b.age += dt.toFloat()
            if (b.age > 0.6f) it.remove()
        }

        if (shakeTime > 0f) shakeTime = max(0f, shakeTime - dt.toFloat())

        // İz: küre görünürken her karede nokta bırak, hepsini soldur
        if (orbVisible && orbState !is OrbState.Dead) {
            trail.addLast(TrailPoint(orbX, orbY))
            if (trail.size > 26) trail.removeFirst()
        }
        val ti = trail.iterator()
        while (ti.hasNext()) {
            val t = ti.next()
            t.age += dt.toFloat()
            if (t.age > 0.5f) ti.remove()
        }

        // Bonus geri sayımı (ölüyken de akar)
        if (isBonus && !finished) {
            val remaining = ceil(bonusDeadline - elapsed).toInt()
            if (remaining != lastBonusTick && remaining >= 0) {
                lastBonusTick = remaining
                onEvent?.invoke(GameEvent.BonusTick(remaining))
            }
            if (elapsed >= bonusDeadline) finishBonus()
        }

        // Süreli bölüm geri sayımı — yalnızca küre oyundayken işler
        timedDeadline?.let { deadline ->
            if (!finished) {
                val active = orbState is OrbState.Attached || orbState is OrbState.Flying
                if (active) {
                    val remaining = ceil(deadline - elapsed).toInt()
                    if (remaining != lastTimeTickSent && remaining >= 0) {
                        lastTimeTickSent = remaining
                        onEvent?.invoke(GameEvent.TimeTick(remaining))
                    }
                    if (elapsed >= deadline) fail()   // süre doldu — deneme yandı
                }
            }
        }

        when (val s = orbState) {
            is OrbState.Attached -> {
                val spec = ringSpecs[s.ring]
                val angle = s.angle + spec.orbitSpeed * s.direction * dt.toFloat()
                orbState = OrbState.Attached(s.ring, angle, s.direction)
                val (cx, cy) = ringCenter(s.ring)
                val r = ringRadius(s.ring)
                orbX = cx + cos(angle) * r
                orbY = cy + sin(angle) * r
                if (!hazardGraceActive && hazardContains(s.ring, angle)) { fail(); return }
                checkLumens()
                // Süre dolunca ceza yok: küre kendiliğinden fırlar. Yayın son
                // üçte biri kırmızıya döndüğünde oyuncu bunun geldiğini görür
                // ve isterse daha iyi bir açıda kendi fırlatır.
                val limit = dwellLimit
                if (limit != null && !spec.isGate) {
                    dwellVisible = true
                    dwellFraction = max(0f, 1f - ((elapsed - dwellStart) / limit).toFloat())
                    if (dwellFraction <= 0f) {
                        dwellVisible = false
                        launch(s.ring, angle, s.direction)
                    }
                } else {
                    dwellVisible = false
                }
            }

            is OrbState.Flying -> {
                dwellVisible = false
                flightTime += dt
                orbX += s.vx * dt.toFloat()
                orbY += s.vy * dt.toFloat()
                checkCapture()
                checkLumens()
                checkBounds()
                if (flightTime > maxFlightTime) missedShot()
            }

            OrbState.Dead -> {
                dwellVisible = false
                val since = deadSince
                if (since != null && elapsed - since >= respawnDelay) {
                    if (mode is GameMode.Endless) {
                        if (extraLives > 0) {
                            extraLives--
                            reviveEndless()
                            burst(orbX, orbY, 24, FxColor.LUMEN)
                            onEvent?.invoke(GameEvent.ExtraLifeUsed(extraLives))
                        } else if (!endlessOverSent) {
                            endlessOverSent = true
                            onEvent?.invoke(GameEvent.EndlessGameOver(endlessScore))
                        }
                    } else if (!finished) {
                        if (restartsOnDeath) restartLevel() else respawn()
                    }
                }
            }

            OrbState.Won -> dwellVisible = false
        }

        if (mode is GameMode.Endless) updateEndlessCamera(dt)
    }

    // MARK: Yakalama, tehlike, ödül

    private fun checkCapture() {
        for (i in ringSpecs.indices) {
            val (cx, cy) = ringCenter(i)
            val dx = orbX - cx
            val dy = orbY - cy
            val dist = sqrt(dx * dx + dy * dy)
            val r = ringRadius(i)

            if (i == lastRing && !exitedLastRing) {
                if (dist > r + orbRadiusPx * 2) exitedLastRing = true
                continue
            }
            if (dist > r) continue

            val angle = atan2(dy, dx)
            // Müsamaha kapalıyken kırmızıya konmak da ölümdür. Açıkken bu ilk
            // temas öldürmez; tur sayacı başlar.
            if (!hazardGraceEnabled && hazardContains(i, angle)) { fail(); return }

            // Küre halkanın SOL yarısına geldiyse saat yönünün tersine, SAĞ
            // yarısına geldiyse saat yönünde döner. Ekran ekseni iOS'un tersi
            // olduğu için işaret de ters: aynı görüntüyü veren değer bu.
            val direction = if (dx < 0) -1f else 1f
            orbState = OrbState.Attached(i, angle, direction)
            startHazardGraceIfNeeded(i)
            dwellStart = elapsed
            combo++
            burst(orbX, orbY, 10, FxColor.ACCENT)

            if (ringSpecs[i].isGate && gateOpen) {
                win()
            } else {
                onEvent?.invoke(GameEvent.Hop(combo))
                onEvent?.invoke(
                    GameEvent.Attached(
                        ringSpecs[i].hazardArcs.isNotEmpty(),
                        ringSpecs[i].moving != null
                    )
                )
                if (mode is GameMode.Endless && i > endlessScore) {
                    endlessScore = i
                    onEvent?.invoke(GameEvent.EndlessScore(endlessScore))
                    extendEndlessIfNeeded(i)
                }
            }
            return
        }
    }

    /**
     * Tehlikeli bir halkaya tutunulduğunda bir tam turluk müsamaha başlatır.
     * Süre halkanın kendi dönüş hızından hesaplanır: hızlı halkada kısa,
     * yavaş halkada uzun — her zaman TAM BİR TUR eder.
     */
    private fun startHazardGraceIfNeeded(ring: Int) {
        if (!hazardGraceEnabled || ringSpecs[ring].hazardArcs.isEmpty()) {
            hazardGraceUntil = null
            return
        }
        val speed = max(0.1f, ringSpecs[ring].orbitSpeed)
        hazardGraceUntil = elapsed + (2 * PI / speed)
    }

    /** Verilen açı, halkanın kırmızı yaylarından birinin üstünde mi? */
    fun hazardContains(ring: Int, angle: Float): Boolean {
        val spec = ringSpecs[ring]
        if (spec.hazardArcs.isEmpty()) return false
        val rot = elapsed.toFloat() * spec.hazardRotationSpeed
        val twoPi = (2 * PI).toFloat()
        for (arc in spec.hazardArcs) {
            var rel = (angle - rot - arc.start) % twoPi
            if (rel < 0) rel += twoPi
            if (rel <= (arc.end - arc.start)) return true
        }
        return false
    }

    /** Toplanan lumenlerin yıldız değeri toplamı (büyük yıldız 4 eder) */
    val collectedStars: Int
        get() = lumenCollected.indices.sumOf { if (lumenCollected[it]) lumenValues[it] else 0 }

    /** Topla-bitir bölümünde kapı, her lumen toplanana kadar kapalıdır. */
    private val gateOpen: Boolean
        get() = !gateNeedsAllLumens || lumenCollected.all { it }

    private fun checkLumens() {
        for (i in lumens.indices) {
            if (lumenCollected[i]) continue
            val (lx, ly) = lumenPoint(i)
            val dx = lx - orbX
            val dy = ly - orbY
            val reach = if (lumenValues[i] > 1) collectDistance * 1.3f else collectDistance
            if (sqrt(dx * dx + dy * dy) < reach) {
                lumenCollected[i] = true
                burst(lx, ly, if (lumenValues[i] > 1) 26 else 16, FxColor.LUMEN)
                onEvent?.invoke(GameEvent.Collect(collectedStars))
                if (isBonus && lumenCollected.all { it }) finishBonus()
                // Topla-bitir: son lumen kapıyı açar. Küre zaten kapının
                // üstünde dönüyorsa bölüm o anda biter.
                if (gateNeedsAllLumens && gateOpen) {
                    val s = orbState
                    if (s is OrbState.Attached && ringSpecs[s.ring].isGate) {
                        win()
                    } else {
                        val gate = ringSpecs.indexOfFirst { it.isGate }
                        if (gate >= 0) {
                            val (gx, gy) = ringCenter(gate)
                            burst(gx, gy, 22, FxColor.GATE)
                        }
                        onEvent?.invoke(GameEvent.GateUnlocked)
                    }
                }
            }
        }
    }

    private fun checkBounds() {
        val minY: Float
        val maxY: Float
        val m = 60f * density
        if (mode is GameMode.Endless) {
            minY = cameraY - height / 2f - m - 20f
            maxY = cameraY + height / 2f + m + 20f
        } else {
            minY = -m
            maxY = height + m
        }
        if (orbX < -m || orbX > width + m || orbY < minY || orbY > maxY) missedShot()
    }

    /**
     * Kaçırılan atış: öğrenme bölümlerinde küre fırlatıldığı halkaya geri
     * döner — ceza yok. İleri bölümlerde kaçırmak elenmektir.
     */
    private fun missedShot() {
        if (forgivingBounds) softReturn() else fail()
    }

    /** Küreyi son fırlatıldığı halkaya nazikçe geri oturtur */
    private fun softReturn() {
        if (lastRing >= ringSpecs.size) { fail(); return }
        combo = 0
        val (cx, cy) = ringCenter(lastRing)
        val r = ringRadius(lastRing)
        var angle = atan2(orbY - cy, orbX - cx)
        var tries = 0
        while (hazardContains(lastRing, angle) && tries < 21) {
            angle += 0.3f
            tries++
        }
        orbState = OrbState.Attached(lastRing, angle, ringSpecs[lastRing].direction)
        startHazardGraceIfNeeded(lastRing)
        dwellStart = elapsed
        exitedLastRing = true
        orbX = cx + cos(angle) * r
        orbY = cy + sin(angle) * r
    }

    /**
     * Sonsuz modda ödüllü reklam izlendikten sonra çağrılır: skor korunur,
     * küre son tutunduğu halkaya güvenli bir açıdan geri oturur.
     */
    fun reviveEndless() {
        if (mode !is GameMode.Endless || ringSpecs.isEmpty()) return
        endlessOverSent = false
        deadSince = null
        flightTime = 0.0
        orbVisible = true
        lastRing = lastRing.coerceIn(0, ringSpecs.size - 1)
        softReturn()
        // Kamera yalnızca yukarı taşındığı için ölüm yüksekliğinde asılı
        // kalıyordu: aşağıdaki halkasına dönen küre kadrajın altında kalıyor,
        // dokunulduğu anda da sınır dışı sayılıp anında ölüyordu.
        cameraY = min(orbY - height * 0.18f, height / 2f)
    }

    private fun fail() {
        if (orbState is OrbState.Dead || orbState is OrbState.Won) return
        if (finished) return
        // Canlanma tam öldüğü halkadan devam etsin diye tutunulan halkayı
        // kaydediyoruz; `lastRing` yalnızca fırlatmada güncellendiği için
        // halka üstünde ölünce bir gerideki halkadan başlıyordu.
        (orbState as? OrbState.Attached)?.let { lastRing = it.ring }
        hazardGraceUntil = null
        orbState = OrbState.Dead
        deadSince = elapsed
        combo = 0
        burst(orbX, orbY, 26, FxColor.HAZARD)
        orbVisible = false
        shakeTime = 0.16f
        onEvent?.invoke(GameEvent.Fail)
    }

    private fun respawn() {
        if (ringSpecs.isEmpty() || finished) return
        val start = level?.startRing ?: 0
        deadSince = null
        orbVisible = true
        orbState = OrbState.Attached(start, (-PI / 2).toFloat(), ringSpecs[start].direction)
        startHazardGraceIfNeeded(start)
        dwellStart = elapsed
        dwellVisible = false
        exitedLastRing = true
        val (cx, cy) = ringCenter(start)
        orbX = cx
        orbY = cy - ringRadius(start)
        // Süreli bölümde her deneme dolu süreyle başlar
        level?.timeLimit?.let {
            timedDeadline = elapsed + it
            lastTimeTickSent = Int.MAX_VALUE
        }
    }

    /**
     * Topla-bitir bölümünde ölüm: bölüm sıfırdan kurulur, toplanan bütün
     * lumenler geri gelir. Yarım kalmış bir turu kurtarmak yok — baştan.
     */
    private fun restartLevel() {
        deadSince = null
        combo = 0
        finished = false
        orbVisible = true
        lumenCollected = BooleanArray(lumenSpecs.size)
        lumenValues = lumenSpecs.map { it.value }.toIntArray()
        onEvent?.invoke(GameEvent.Collect(0))
        respawn()
    }

    private fun win() {
        if (finished) return
        finished = true
        orbState = OrbState.Won
        val stars = collectedStars
        burst(orbX, orbY, 40, FxColor.GATE)
        if (stars >= (level?.maxStars ?: 3)) celebrationCascade()
        onEvent?.invoke(GameEvent.Win(stars))
    }

    /** Bonus turu sonu: yıldız sayısı toplanan lumen oranına göre */
    private fun finishBonus() {
        if (finished) return
        finished = true
        orbState = OrbState.Won
        val collected = lumenCollected.count { it }
        val stars = when {
            collected >= lumenTotal -> 3
            collected >= (lumenTotal * 0.66).toInt() -> 2
            collected >= (lumenTotal * 0.33).toInt() -> 1
            else -> 0
        }
        burst(orbX, orbY, 40, FxColor.LUMEN)
        if (stars >= 3) celebrationCascade()
        onEvent?.invoke(GameEvent.Win(stars))
    }

    // MARK: Sonsuz mod

    private fun seedEndless() {
        ringSpecs = listOf(RingSpec(Pt(0.5f, 0.15f), 0.10f, 1.8f, 1f))
        extendEndlessIfNeeded(0)
    }

    private fun extendEndlessIfNeeded(reached: Int) {
        val list = ringSpecs.toMutableList()
        while (list.size < reached + 5) {
            val prev = list[list.size - 1]
            val n = list.size
            val hardness = min(n / 40f, 1f)
            val radius = 0.10f - 0.035f * hardness + endlessRNG.rand(-0.008f, 0.008f)
            val angle = endlessRNG.rand((PI * 0.3).toFloat(), (PI * 0.7).toFloat())
            val dist = endlessRNG.rand(0.26f, 0.34f)
            val cx = (prev.center.x + cos(angle) * dist).coerceIn(0.18f, 0.82f)
            val cy = prev.center.y + sin(angle) * dist

            var arcs: List<ArcRange> = emptyList()
            var rot = 0f
            if (n > 8 && endlessRNG.rand(0f, 1f) < 0.3f + 0.3f * hardness) {
                val span = endlessRNG.rand(
                    (PI * 0.22).toFloat(),
                    (PI * (0.3 + 0.2 * hardness)).toFloat()
                )
                val start = endlessRNG.rand(0f, (2 * PI).toFloat())
                arcs = listOf(ArcRange(start, start + span))
                if (endlessRNG.rand(0f, 1f) < 0.5f) rot = endlessRNG.rand(0.4f, 0.9f)
            }

            list.add(
                RingSpec(
                    center = Pt(cx, cy),
                    radius = radius,
                    orbitSpeed = 1.8f + 1.8f * hardness + endlessRNG.rand(-0.2f, 0.2f),
                    direction = if (endlessRNG.rand(0f, 1f) < 0.5f) 1f else -1f,
                    hazardArcs = arcs,
                    hazardRotationSpeed = rot
                )
            )
        }
        ringSpecs = list
    }

    private fun updateEndlessCamera(dt: Double) {
        // Kamera, ulaşılan son halkanın bir miktar üstünden yukarı ÇIKMAZ.
        // Öncesinde küreyi koşulsuz takip ediyordu: boşluğa atılan küre
        // kadrajdan hiç çıkmıyor, sınırlar da kameraya göre ölçüldüğü için
        // ölüm saniyelerce gecikiyordu. (Ekran ekseni aşağı doğru arttığı
        // için "tavan" burada sayısal olarak alt sınırdır.)
        if (ringSpecs.isEmpty()) return
        val anchorRing = ((orbState as? OrbState.Attached)?.ring ?: lastRing)
            .coerceIn(0, ringSpecs.size - 1)
        val ceiling = ringCenter(anchorRing).second - height * 0.35f
        val targetY = min(orbY - height * 0.18f, height / 2f).coerceAtLeast(ceiling)
        if (targetY < cameraY) {
            cameraY += (targetY - cameraY) * min(1f, (dt * 4).toFloat())
        }
    }

    private fun burst(x: Float, y: Float, count: Int, color: FxColor, delay: Float = 0f) {
        if (bursts.size > 40) return   // efekt yığılmasın
        bursts.add(Burst(x, y, color, count, age = -delay))
    }

    /** 3/3 yıldız kutlaması: ekrana yayılan renkli havai fişek şelalesi */
    private fun celebrationCascade() {
        val palette = listOf(FxColor.LUMEN, FxColor.GATE, FxColor.ACCENT, FxColor.ORB)
        val rng = java.util.Random()
        for (i in 0 until 12) {
            val x = width * (0.15f + rng.nextFloat() * 0.70f)
            val y = height * (0.30f + rng.nextFloat() * 0.55f)
            burst(x, y, 22, palette[i % palette.size], delay = 0.06f * i)
        }
    }
}
