package com.caganhatapci.orbeon.services

import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query

/**
 * Dünya sıralaması — Firestore + anonim Auth.
 *
 * `google-services.json` eklenmemişse Firebase başlatılamaz; bu durumda
 * sıralama sessizce kapalı kalır ve oyunun geri kalanı normal çalışır.
 * iOS sürümüyle AYNI koleksiyonları kullanır, yani tablo ortaktır.
 */
class LeaderboardService {

    enum class Mode(private val base: String) {
        ENDLESS("leaderboard_endless"),
        SPEEDRUN("leaderboard_speedrun");

        /**
         * Her hafta kendi koleksiyonuna yazılır. Tek koleksiyonda `week` alanıyla
         * süzmek Firestore'da bileşik dizin ister; ayrı koleksiyon yalnızca
         * `value` sıralaması kullandığı için ek kurulum gerektirmez.
         */
        fun collection(week: Int): String = "${base}_w$week"
    }

    companion object {
        /**
         * Hafta numarası: sabit bir Pazartesiden (1 Ocak 2024 00:00 UTC) geçen
         * tam hafta sayısı. iOS ile BİREBİR aynı formül — tablo ortak olduğu için
         * iki platformun aynı koleksiyon adını üretmesi şart. Takvim/ISO hafta
         * hesabı yerine bu kullanılıyor: java.time minSdk 24'te desugaring
         * istiyor, bu aritmetik ise her yerde aynı sonucu veriyor.
         */
        private const val WEEK_ANCHOR_SECONDS = 1_704_067_200L   // 2024-01-01, Pazartesi, UTC
        private const val WEEK_LENGTH_SECONDS = 7L * 24 * 60 * 60

        fun currentWeek(): Int =
            Math.floorDiv(System.currentTimeMillis() / 1000 - WEEK_ANCHOR_SECONDS,
                          WEEK_LENGTH_SECONDS).toInt()

        /** Sıralamanın sıfırlanmasına kalan saniye */
        fun secondsUntilReset(): Long {
            val nextStart = WEEK_ANCHOR_SECONDS + (currentWeek() + 1L) * WEEK_LENGTH_SECONDS
            return (nextStart - System.currentTimeMillis() / 1000).coerceAtLeast(0)
        }
    }

    data class Entry(val username: String, val value: Double, val playerId: String)

    var isConfigured by mutableStateOf(false)
        private set
    var entries by mutableStateOf<List<Entry>>(emptyList())
        private set
    var loading by mutableStateOf(false)
        private set

    private var db: FirebaseFirestore? = null

    fun configureIfPossible() {
        if (isConfigured) return
        runCatching {
            db = FirebaseFirestore.getInstance()
            val auth = FirebaseAuth.getInstance()
            if (auth.currentUser == null) auth.signInAnonymously()
            isConfigured = true
        }.onFailure {
            Log.w("Orbeon.Leaderboard", "Firebase yok, sıralama kapalı: ${it.message}")
            isConfigured = false
        }
    }

    /**
     * Skoru gönderir. Aynı oyuncu için tek satır tutulur; sonsuz modda daha
     * YÜKSEK, speed run'da daha DÜŞÜK değer kazanır.
     */
    fun submit(mode: Mode, value: Double, username: String, playerId: String) {
        val database = db ?: return
        if (username.isBlank()) return
        // Sonsuz modda 0, "oynadım" değil "ilk halkadan atlayamadım" demek.
        // Tabloyu sıfırlarla doldurmanın kimseye faydası yok; hız turunda ise
        // düşük değer İYİ olduğu için aynı eşik uygulanamaz.
        if (mode == Mode.ENDLESS && value < 1.0) return
        val doc = database.collection(mode.collection(currentWeek())).document(playerId)
        doc.get().addOnSuccessListener { snapshot ->
            val existing = snapshot.getDouble("value")
            val better = when (mode) {
                Mode.ENDLESS -> existing == null || value > existing
                Mode.SPEEDRUN -> existing == null || value < existing
            }
            if (!better) return@addOnSuccessListener
            doc.set(
                mapOf(
                    "username" to username,
                    "value" to value,
                    "playerID" to playerId,
                    "updatedAt" to System.currentTimeMillis()
                )
            )
        }
    }

    fun load(mode: Mode, limit: Long = 50) {
        val database = db ?: return
        loading = true
        val direction = if (mode == Mode.ENDLESS) Query.Direction.DESCENDING else Query.Direction.ASCENDING
        database.collection(mode.collection(currentWeek()))
            .orderBy("value", direction)
            .limit(limit)
            .get()
            .addOnSuccessListener { snap ->
                entries = snap.documents.mapNotNull { doc ->
                    val name = doc.getString("username") ?: return@mapNotNull null
                    val value = doc.getDouble("value") ?: return@mapNotNull null
                    // Eskiden yazılmış 0 skorlar tabloda duruyor; okurken de
                    // eleniyorlar ki kimse sıfırla sıralamada yer tutmasın
                    if (mode == Mode.ENDLESS && value < 1.0) return@mapNotNull null
                    Entry(name, value, doc.getString("playerID") ?: doc.id)
                }
                loading = false
            }
            .addOnFailureListener {
                Log.e("Orbeon.Leaderboard", "Sıralama yüklenemedi: ${it.message}")
                loading = false
            }
    }
}
