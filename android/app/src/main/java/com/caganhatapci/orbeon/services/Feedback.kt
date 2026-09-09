package com.caganhatapci.orbeon.services

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import com.caganhatapci.orbeon.BuildConfig
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import java.util.Calendar

/**
 * Ayarlardaki görüş/öneri kutusunun arkası — iOS'taki `Feedback`'in karşılığı.
 *
 * Firestore'daki `feedback` koleksiyonuna yazar; iki platform AYNI koleksiyona
 * yazıyor, `platform` alanı hangisinden geldiğini söylüyor. Mağaza yorumları
 * geliştiriciye ulaşmıyor, e-posta bağlantısını da kimse açmıyor; oyuncunun
 * bir şey söyleyebileceği tek pratik yer bu.
 */
class Feedback(context: Context) {

    companion object {
        /** Metin sınırı. Doğrudan bir Firestore belgesine gittiği için sınırsız değil. */
        const val MAX_LENGTH = 1000

        /**
         * Günde kaç mesaj. Sınırsız bırakılsa tek bir kişi gece boyunca
         * yüzlerce belge yazabilir — hem Firestore faturası hem de gerçek
         * geri bildirimin bunun içinde kaybolması. İkisi, söyleyecek sözü
         * olan birine yeter.
         */
        const val DAILY_LIMIT = 2

        private const val DAY_KEY = "feedback.day"
        private const val COUNT_KEY = "feedback.count"
    }

    private val p = context.getSharedPreferences("orbeon", Context.MODE_PRIVATE)

    /**
     * Bugünün gün numarası (1970'ten beri). Saat dilimi cihazın kendisi:
     * oyuncunun "bugün"ü neyse o.
     */
    private val today: Int
        get() {
            val c = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }
            return (c.timeInMillis / 86_400_000L).toInt()
        }

    /**
     * Bugün kaç hak kaldı. Compose durumu: gönderimden sonra kutunun
     * üstündeki sayı kendiliğinden düşüyor.
     */
    var remainingToday by mutableIntStateOf(0)
        private set

    init { refresh() }

    fun refresh() {
        remainingToday =
            if (p.getInt(DAY_KEY, -1) != today) DAILY_LIMIT
            else (DAILY_LIMIT - p.getInt(COUNT_KEY, 0)).coerceAtLeast(0)
    }

    /**
     * Hak yalnızca GÖNDERİM BAŞARILI olunca düşüyor: ağ koptuğu için
     * gitmeyen bir mesaj oyuncunun hakkını yakmamalı.
     */
    private fun consume() {
        if (p.getInt(DAY_KEY, -1) != today) {
            p.edit().putInt(DAY_KEY, today).putInt(COUNT_KEY, 0).apply()
        }
        p.edit().putInt(COUNT_KEY, p.getInt(COUNT_KEY, 0) + 1).apply()
        refresh()
    }

    /** Gönderilebilir mi — düğmenin açık olup olmadığı da bunu soruyor. */
    fun canSend(message: String): Boolean {
        val trimmed = message.trim()
        return remainingToday > 0 && trimmed.length >= 4 && trimmed.length <= MAX_LENGTH
    }

    /**
     * `onResult(true)` = yazıldı. Ağ hatasında, günlük hak bittiyse ya da
     * metin çok kısaysa false.
     *
     * Belge kimliği rastgele; aynı kişi birden çok kez yazabilsin diye
     * playerId kullanılmıyor.
     */
    fun send(message: String, playerId: String, username: String, onResult: (Boolean) -> Unit) {
        if (!canSend(message)) { onResult(false); return }
        val clipped = message.trim().take(MAX_LENGTH)

        val data = hashMapOf<String, Any>(
            "message" to clipped,
            "playerID" to playerId,
            "platform" to "Android",
            "version" to BuildConfig.VERSION_NAME,
            "sentAt" to FieldValue.serverTimestamp()
        )
        if (username.isNotBlank()) data["username"] = username

        runCatching {
            FirebaseFirestore.getInstance().collection("feedback")
                .add(data)
                .addOnSuccessListener { consume(); onResult(true) }
                .addOnFailureListener {
                    Diagnostics.record("Görüş gönderilemedi: ${it.message}", domain = "Feedback")
                    onResult(false)
                }
        }.onFailure {
            Diagnostics.record("Görüş gönderilemedi: ${it.message}", domain = "Feedback")
            onResult(false)
        }
    }
}
