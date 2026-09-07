package com.caganhatapci.orbeon.services

import android.content.Context
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.firebase.firestore.FirebaseFirestore
import java.util.Locale

/**
 * Ana menüde gösterilen duyuru kartı — "yeni sürüm çıktı", "bu hafta çift
 * yıldız" gibi. iOS'takiyle AYNI Firestore belgesini okuyor, yani bir kez
 * yazılan duyuru iki platformda birden görünüyor.
 *
 * Belge alanları:
 *   enabled     Bool    — kapalıysa hiçbir şey gösterilmez
 *   id          String  — "kapat" takibi bunun üzerinden
 *   title/body  String  — İngilizce taban
 *   title_tr / body_tr / …  — dile göre karşılık (varsa)
 *   minVersion  String  — uygulama bu sürümdeyse ya da üstündeyse GÖSTERİLMEZ
 *   playStoreId String  — düğme Play'de bu paketi açar; yoksa düğme yok
 */
class Announcement(private val context: Context) {

    data class Item(
        val id: String,
        val title: String,
        val body: String,
        val storeId: String?
    )

    var current by mutableStateOf<Item?>(null)
        private set

    private var didLoad = false
    private val p = context.getSharedPreferences("orbeon", Context.MODE_PRIVATE)

    /**
     * Menü açılınca çağrılır. Oturumda bir kez okuyor — duyuru her açılışta
     * yeniden indirilecek kadar önemli değil, ama uygulama yeniden başlarsa
     * tazeleniyor.
     */
    fun refreshIfNeeded(appVersion: String, push: PushManager?) {
        if (didLoad) return
        didLoad = true
        runCatching {
            FirebaseFirestore.getInstance().collection("config").document("announcement")
                .get()
                .addOnSuccessListener { snap ->
                    val data = snap.data ?: return@addOnSuccessListener
                    current = resolve(data, appVersion, Locale.getDefault().language)
                    // Aynı haber birkaç saat sonra bildirim olarak da düşsün:
                    // kartı görüp "sonra" diyene ikinci bir dokunuş.
                    push?.syncUpdateReminder(current?.title, current?.body)
                }
        }.onFailure { Log.w("Orbeon.Announcement", "Duyuru okunamadı: ${it.message}") }
    }

    /**
     * Ham alanlardan gösterilecek duyuruyu çıkarır. Saf fonksiyon: sürüm
     * karşılaştırması ve dil seçimi Firebase'e bağlanmadan da denenebilsin.
     */
    fun resolve(data: Map<String, Any?>, appVersion: String, language: String): Item? {
        if (data["enabled"] as? Boolean == false) return null
        val id = data["id"] as? String ?: return null
        if (id.isBlank()) return null
        if (p.getBoolean("announcement.seen.$id", false)) return null

        // Güncelleme çağrısı: hedeflenen sürüme ulaşmış olana gösterme
        val minVersion = data["minVersion"] as? String
        if (!minVersion.isNullOrBlank() && compare(appVersion, minVersion) >= 0) return null

        val lang = language.lowercase().split("-").first()
        fun field(name: String): String? =
            (data["${name}_$lang"] as? String) ?: (data[name] as? String)

        val title = field("title")?.takeIf { it.isNotBlank() } ?: return null
        val body = field("body")?.takeIf { it.isNotBlank() } ?: return null
        val storeId = (data["playStoreId"] as? String)?.takeIf { it.isNotBlank() }
        return Item(id, title, body, storeId)
    }

    /**
     * "2.10" > "2.9" olmalı: parça parça SAYI karşılaştırması, metin değil.
     * Düz string karşılaştırması "2.10" < "2.9" derdi.
     */
    fun compare(a: String, b: String): Int {
        val lhs = a.split(".").map { it.toIntOrNull() ?: 0 }
        val rhs = b.split(".").map { it.toIntOrNull() ?: 0 }
        for (i in 0 until maxOf(lhs.size, rhs.size)) {
            val l = lhs.getOrElse(i) { 0 }
            val r = rhs.getOrElse(i) { 0 }
            if (l != r) return if (l < r) -1 else 1
        }
        return 0
    }

    fun dismiss(push: PushManager?) {
        val item = current ?: return
        p.edit().putBoolean("announcement.seen.${item.id}", true).apply()
        current = null
        // Kartı kapatan haberi almış demektir; bildirimi de düşürmek aynı
        // şeyi ikinci kez söylemek olurdu
        push?.syncUpdateReminder(null, null)
    }
}
