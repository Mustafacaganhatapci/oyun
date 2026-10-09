package com.caganhatapci.orbeon.services

import android.util.Log
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore

/**
 * Firestore'dan gelen kodun ne verdiği.
 *
 * trialDays > 0 ise SÜRELİ premium, 0 ise kalıcı. Belgeye `trialDays` alanı
 * yazarak kampanyanın ödülü konsoldan ayarlanıyor — yeni bir kod ya da farklı
 * bir süre için artık sürüm göndermek gerekmiyor. Bu eksikti ve bir
 * kampanyanın ortasında anlaşıldı.
 */
data class PromoRedemption(val trialDays: Int)

/**
 * Firestore'daki `promoCodes` koleksiyonundan premium kodu kullanır.
 * iOS ile AYNI koleksiyonu okur — kod bir kez tanımlanır, iki platformda çalışır.
 *
 * Belge kimliği kodun küçük harfli hâli. Alanlar:
 *   active   (bool)   — false ise kod kapalı
 *   maxUses  (int)    — 0 ya da yok: sınırsız
 *   uses     (int)    — kaç kez kullanıldı (biz artırırız)
 *   note     (string) — kimin için verildiği, yalnızca geliştirici için
 *   trialDays(int)    — 0/yok: kalıcı premium. >0: o kadar günlük deneme
 *
 * İşlem (transaction) içinde okunup artırılır: aynı anda iki kişi son hakkı
 * kullanamaz. Aynı oyuncu kodu tekrar girerse hak harcanmaz — telefon
 * değiştiren biri kodunu yeniden kullanabilsin diye.
 */
object PromoCodes {

    private const val TAG = "Orbeon.Promo"

    fun redeem(code: String, playerId: String, onResult: (PromoRedemption?) -> Unit) {
        val db = runCatching { FirebaseFirestore.getInstance() }.getOrNull()
        if (db == null) { onResult(null); return }

        val doc = db.collection("promoCodes").document(code)
        db.runTransaction { transaction ->
            val snapshot = transaction.get(doc)
            if (!snapshot.exists()) return@runTransaction -1
            if (snapshot.getBoolean("active") == false) return@runTransaction -1

            // 0 = kalıcı premium, >0 = o kadar günlük deneme
            val trialDays = maxOf(0, (snapshot.getLong("trialDays") ?: 0L).toInt())

            @Suppress("UNCHECKED_CAST")
            val redeemers = (snapshot.get("redeemedBy") as? List<String> ?: emptyList()).toMutableList()
            if (redeemers.contains(playerId)) return@runTransaction trialDays

            val uses = (snapshot.getLong("uses") ?: 0L).toInt()
            val maxUses = (snapshot.getLong("maxUses") ?: 0L).toInt()
            if (maxUses > 0 && uses >= maxUses) return@runTransaction -1

            // Liste sınırsız büyümesin: son 50 kullanan tutulur
            redeemers.add(playerId)
            while (redeemers.size > 50) redeemers.removeAt(0)

            transaction.update(
                doc,
                mapOf(
                    "uses" to uses + 1,
                    "redeemedBy" to redeemers,
                    "lastRedeemedAt" to FieldValue.serverTimestamp()
                )
            )
            trialDays
        }.addOnSuccessListener { days ->
            // -1 = reddedildi. Ağ hatasında da null dönülüyor; çağıran o
            // zaman gömülü listeye düşüyor.
            val d = (days as? Int) ?: -1
            onResult(if (d >= 0) PromoRedemption(d) else null)
        }.addOnFailureListener { error ->
            Log.e(TAG, "Kod okunamadı promoCodes/$code: ${error.message}")
            onResult(null)
        }
    }
}
