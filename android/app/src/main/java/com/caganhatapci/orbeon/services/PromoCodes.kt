package com.caganhatapci.orbeon.services

import android.util.Log
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore

/**
 * Firestore'daki `promoCodes` koleksiyonundan premium kodu kullanır.
 * iOS ile AYNI koleksiyonu okur — kod bir kez tanımlanır, iki platformda çalışır.
 *
 * Belge kimliği kodun küçük harfli hâli. Alanlar:
 *   active   (bool)   — false ise kod kapalı
 *   maxUses  (int)    — 0 ya da yok: sınırsız
 *   uses     (int)    — kaç kez kullanıldı (biz artırırız)
 *   note     (string) — kimin için verildiği, yalnızca geliştirici için
 *
 * İşlem (transaction) içinde okunup artırılır: aynı anda iki kişi son hakkı
 * kullanamaz. Aynı oyuncu kodu tekrar girerse hak harcanmaz — telefon
 * değiştiren biri kodunu yeniden kullanabilsin diye.
 */
object PromoCodes {

    private const val TAG = "Orbeon.Promo"

    fun redeem(code: String, playerId: String, onResult: (Boolean) -> Unit) {
        val db = runCatching { FirebaseFirestore.getInstance() }.getOrNull()
        if (db == null) { onResult(false); return }

        val doc = db.collection("promoCodes").document(code)
        db.runTransaction { transaction ->
            val snapshot = transaction.get(doc)
            if (!snapshot.exists()) return@runTransaction false
            if (snapshot.getBoolean("active") == false) return@runTransaction false

            @Suppress("UNCHECKED_CAST")
            val redeemers = (snapshot.get("redeemedBy") as? List<String> ?: emptyList()).toMutableList()
            if (redeemers.contains(playerId)) return@runTransaction true

            val uses = (snapshot.getLong("uses") ?: 0L).toInt()
            val maxUses = (snapshot.getLong("maxUses") ?: 0L).toInt()
            if (maxUses > 0 && uses >= maxUses) return@runTransaction false

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
            true
        }.addOnSuccessListener { accepted ->
            onResult(accepted == true)
        }.addOnFailureListener { error ->
            Log.e(TAG, "Kod okunamadı promoCodes/$code: ${error.message}")
            onResult(false)
        }
    }
}
