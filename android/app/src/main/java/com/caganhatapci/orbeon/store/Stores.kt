package com.caganhatapci.orbeon.store

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.toMutableStateList
import com.caganhatapci.orbeon.R
import com.caganhatapci.orbeon.model.LevelLibrary
import com.caganhatapci.orbeon.model.OrbStyle
import com.caganhatapci.orbeon.model.OrbUnlock
import com.caganhatapci.orbeon.model.SplitMix64
import com.caganhatapci.orbeon.theme.Theme
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.UUID
import kotlin.math.max
import kotlin.math.min

private const val PREFS = "orbeon.prefs"

fun prefs(context: Context): SharedPreferences =
    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

/**
 * Oyuncu ilerlemesi. Kaynak her zaman cihazdaki SharedPreferences'tır;
 * Android'de yedekleme, manifest'teki allowBackup + auto backup ile
 * sistem tarafından yapılır (iOS'taki iCloud yedeklemesinin karşılığı).
 */
class ProgressStore(context: Context) {
    private val p = prefs(context)

    var stars by mutableStateOf(loadStars())
        private set
    var endlessBest by mutableIntStateOf(p.getInt("progress.endlessBest", 0))
        private set
    var speedrunBest by mutableStateOf(p.getFloat("progress.speedrunBest", 0f).toDouble())
        private set
    var totalHops by mutableIntStateOf(p.getInt("progress.totalHops", 0))
        private set
    var spentStars by mutableIntStateOf(p.getInt("progress.spentStars", 0))
        private set
    var bonusStars by mutableIntStateOf(p.getInt("progress.bonusStars", 0))
        private set
    var unlockedOrbs by mutableStateOf(p.getStringSet("progress.unlockedOrbs", emptySet())!!.toSet())
        private set

    private fun loadStars(): Map<Int, Int> {
        val raw = p.getString("progress.stars", null) ?: return emptyMap()
        return runCatching {
            val json = JSONObject(raw)
            json.keys().asSequence().associate { it.toInt() to json.getInt(it) }
        }.getOrDefault(emptyMap())
    }

    private fun saveStars() {
        val json = JSONObject()
        stars.forEach { (k, v) -> json.put(k.toString(), v) }
        p.edit().putString("progress.stars", json.toString()).apply()
    }

    /** Tamamlanan en yüksek bölüm + 1 oynanabilir; 1. bölüm her zaman açık. */
    val highestUnlocked: Int
        get() = min((stars.keys.maxOrNull() ?: 0) + 1, LevelLibrary.COUNT)

    val completedCount: Int get() = stars.size
    val totalStars: Int get() = stars.values.sum() + bonusStars

    /** Harcanabilir yıldız bakiyesi */
    val availableStars: Int get() = max(0, totalStars - spentStars)

    val endlessUnlocked: Boolean get() = stars.containsKey(LevelLibrary.AD_FREE_LEVELS)

    fun isUnlocked(level: Int): Boolean = level <= highestUnlocked

    fun grantBonusStars(amount: Int) {
        bonusStars += amount
        p.edit().putInt("progress.bonusStars", bonusStars).apply()
    }

    fun isOrbUnlocked(style: OrbStyle): Boolean = when (style.unlock) {
        is OrbUnlock.Free -> true
        is OrbUnlock.Premium -> false      // premium ayrı yönetilir (BillingManager)
        is OrbUnlock.Stars -> unlockedOrbs.contains(style.id)
    }

    fun canAfford(style: OrbStyle): Boolean {
        val cost = style.starCost ?: return false
        return availableStars >= cost
    }

    /** Yeterli yıldız varsa satın alır; başarılıysa true döner. */
    fun purchaseOrb(style: OrbStyle): Boolean {
        val cost = style.starCost ?: return false
        if (isOrbUnlocked(style) || availableStars < cost) return false
        spentStars += cost
        unlockedOrbs = unlockedOrbs + style.id
        p.edit()
            .putInt("progress.spentStars", spentStars)
            .putStringSet("progress.unlockedOrbs", unlockedOrbs)
            .apply()
        return true
    }

    fun complete(level: Int, newStars: Int) {
        val existing = stars[level] ?: 0
        stars = stars + (level to max(existing, newStars))
        saveStars()
    }

    fun recordHop() {
        totalHops++
        p.edit().putInt("progress.totalHops", totalHops).apply()
    }

    fun recordEndless(score: Int) {
        if (score > endlessBest) {
            endlessBest = score
            p.edit().putInt("progress.endlessBest", endlessBest).apply()
        }
    }

    /** Yeni rekor ise true döner */
    fun recordSpeedrun(time: Double): Boolean {
        if (speedrunBest == 0.0 || time < speedrunBest) {
            speedrunBest = time
            p.edit().putFloat("progress.speedrunBest", time.toFloat()).apply()
            return true
        }
        return false
    }
}

/** Tema, küre stili, ses ve titreşim tercihleri. */
class SettingsStore(context: Context) {
    private val p = prefs(context)

    var themeId by mutableStateOf(p.getString("settings.theme", "nebula")!!)
    var orbStyleId by mutableStateOf(p.getString("settings.orbStyle", "classic")!!)
    var soundOn by mutableStateOf(p.getBoolean("settings.sound", true))
    var musicOn by mutableStateOf(p.getBoolean("settings.music", true))
    var hapticsOn by mutableStateOf(p.getBoolean("settings.haptics", true))
    /**
     * Renk körlüğü modu — oynanışı belirleyen renkleri her renk körlüğü
     * türünde ayrışan bir palete çevirir ve tehlike yaylarına şekil ipucu
     * ekler.
     */
    var colorBlindOn by mutableStateOf(p.getBoolean("settings.colorBlind", false))

    /**
     * Oyunun her yerinde kullanılan tema. Renk körlüğü modu burada
     * uygulanıyor: tek noktadan geçtiği için menü, HUD ve oyun alanı
     * kendiliğinden aynı paleti görüyor.
     */
    val theme: Theme
        get() = Theme.byId(themeId).let { if (colorBlindOn) it.colorBlindSafe else it }

    fun persist() {
        p.edit()
            .putString("settings.theme", themeId)
            .putString("settings.orbStyle", orbStyleId)
            .putBoolean("settings.sound", soundOn)
            .putBoolean("settings.music", musicOn)
            .putBoolean("settings.haptics", hapticsOn)
            .putBoolean("settings.colorBlind", colorBlindOn)
            .apply()
    }
}

/** Sıralamada görünen ad ve cihaza özel kalıcı kimlik. */
class PlayerStore(context: Context) {
    private val p = prefs(context)

    var username by mutableStateOf(p.getString("player.username", "")!!)
    val playerId: String

    init {
        val existing = p.getString("player.id", null)
        playerId = existing ?: UUID.randomUUID().toString().also {
            p.edit().putString("player.id", it).apply()
        }
    }

    val hasUsername: Boolean get() = username.trim().isNotEmpty()

    fun save(name: String) {
        username = name.trim()
        p.edit().putString("player.username", username).apply()
    }
}

/**
 * Günlük giriş ödülü — art arda gelen günlerde artan yıldız verir.
 * Bir gün kaçırılırsa seri başa döner; ödül gün başına bir kez alınır.
 */
class DailyRewardStore(context: Context) {
    private val p = prefs(context)

    var streak by mutableIntStateOf(p.getInt("daily.streak", 0))
        private set
    var claimedToday by mutableStateOf(false)
        private set

    init { refresh() }

    private val startOfToday: Long
        get() = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }.timeInMillis

    private val lastClaimDay: Long get() = p.getLong("daily.lastClaim", 0L)

    private fun daysBetween(a: Long, b: Long): Int =
        ((b - a) / (24L * 60 * 60 * 1000)).toInt()

    /** Ödül alınırsa serinin kaçıncı günü olacağı (0 tabanlı) */
    private val effectiveStreak: Int
        get() {
            if (lastClaimDay == 0L) return 0
            return if (daysBetween(lastClaimDay, startOfToday) == 1) streak else 0
        }

    val todayReward: Int
        get() = LADDER[effectiveStreak.coerceIn(0, LADDER.size - 1)]

    /** Seri kırıldıysa sayacı düşürüp arayüzü tazeler. */
    fun refresh() {
        if (lastClaimDay == 0L) { claimedToday = false; return }
        val days = daysBetween(lastClaimDay, startOfToday)
        claimedToday = days == 0
        if (days > 1) {
            streak = 0
            p.edit().putInt("daily.streak", 0).apply()
        }
    }

    /** Bugünün ödülünü verir. Zaten alındıysa null döner. */
    fun claim(): Int? {
        refresh()
        if (claimedToday) return null
        val reward = todayReward
        streak = effectiveStreak + 1
        claimedToday = true
        p.edit()
            .putInt("daily.streak", streak)
            .putLong("daily.lastClaim", startOfToday)
            .apply()
        return reward
    }

    companion object {
        /** 7 günlük döngü; 7. günden sonra son basamak tekrar eder. */
        val LADDER = listOf(5, 10, 15, 20, 30, 40, 60)
    }
}

/**
 * Günlük görevler — her gün 3 görev, tamamlananın ödülü yıldız olarak alınır.
 * Görev listesi güne göre deterministik seçilir (aynı gün = aynı görevler).
 */
class MissionStore(context: Context) {
    private val p = prefs(context)

    data class Mission(
        val id: String,
        val titleRes: Int,
        val target: Int,
        val reward: Int,
        var progress: Int,
        var claimed: Boolean
    ) {
        val isComplete: Boolean get() = progress >= target
        val fraction: Float get() = min(1f, progress.toFloat() / max(1, target).toFloat())
    }

    private enum class Template(val target: Int, val reward: Int, val titleRes: Int) {
        LEVELS3(3, 15, R.string.mission_levels3),
        LEVELS5(5, 25, R.string.mission_levels5),
        STARS30(30, 20, R.string.mission_stars30),
        HOPS150(150, 15, R.string.mission_hops150),
        LUMENS40(40, 20, R.string.mission_lumens40),
        NO_DEATH(1, 30, R.string.mission_nodeath)
    }

    var missions by mutableStateOf<List<Mission>>(emptyList())
        private set

    init { reloadForToday() }

    val unclaimedCount: Int get() = missions.count { it.isComplete && !it.claimed }

    fun reloadForToday() {
        val today = dayKey()
        if (p.getString("missions.day", null) != today) {
            p.edit()
                .putString("missions.day", today)
                .remove("missions.progress")
                .remove("missions.claimed")
                .apply()
        }
        val progressJson = runCatching {
            JSONObject(p.getString("missions.progress", "{}") ?: "{}")
        }.getOrDefault(JSONObject())
        val claimed = p.getStringSet("missions.claimed", emptySet()) ?: emptySet()

        missions = todaysTemplates().map { t ->
            Mission(
                id = t.name,
                titleRes = t.titleRes,
                target = t.target,
                reward = t.reward,
                progress = progressJson.optInt(t.name, 0),
                claimed = claimed.contains(t.name)
            )
        }
    }

    fun recordLevelCleared(deathless: Boolean, starsEarned: Int) {
        bump(Template.LEVELS3, 1); bump(Template.LEVELS5, 1)
        if (starsEarned > 0) bump(Template.STARS30, starsEarned)
        if (deathless) bump(Template.NO_DEATH, 1)
    }

    fun recordHops(count: Int) = bump(Template.HOPS150, count)
    fun recordLumens(count: Int) = bump(Template.LUMENS40, count)

    /** Tamamlanmış görevin ödülünü alır; verilecek yıldızı döner. */
    fun claim(id: String): Int? {
        val list = missions.toMutableList()
        val index = list.indexOfFirst { it.id == id }
        if (index < 0) return null
        val m = list[index]
        if (!m.isComplete || m.claimed) return null
        list[index] = m.copy(claimed = true)
        missions = list
        val claimed = (p.getStringSet("missions.claimed", emptySet()) ?: emptySet()).toMutableSet()
        claimed.add(id)
        p.edit().putStringSet("missions.claimed", claimed).apply()
        return m.reward
    }

    private fun bump(template: Template, amount: Int) {
        val list = missions.toMutableList()
        val index = list.indexOfFirst { it.id == template.name }
        if (index < 0 || list[index].claimed) return
        val updated = list[index].copy(progress = list[index].progress + amount)
        list[index] = updated
        missions = list

        val json = runCatching {
            JSONObject(p.getString("missions.progress", "{}") ?: "{}")
        }.getOrDefault(JSONObject())
        json.put(template.name, updated.progress)
        p.edit().putString("missions.progress", json.toString()).apply()
    }

    private fun dayKey(): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    private fun todaysTemplates(): List<Template> {
        var seed = 0L
        for (b in dayKey().toByteArray()) seed = seed * 31 + b
        val rng = SplitMix64(seed)
        return rng.shuffled(Template.entries.toList()).take(3)
    }
}

/** Öğretici adımlarının bir kez gösterilmesini sağlar. */
class TutorialStore(context: Context) {
    private val p = prefs(context)

    enum class Step { LAUNCH, GATE, HAZARD, MOVING, TIMED, BOUNDS }

    private var shown by mutableStateOf(
        (p.getStringSet("tutorial.shown", emptySet()) ?: emptySet()).toSet()
    )

    fun shouldShow(step: Step): Boolean = !shown.contains(step.name)

    fun markShown(step: Step) {
        if (shown.contains(step.name)) return
        shown = shown + step.name
        p.edit().putStringSet("tutorial.shown", shown).apply()
    }

    fun reset() {
        shown = emptySet()
        p.edit().remove("tutorial.shown").apply()
    }
}
