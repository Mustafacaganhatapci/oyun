package com.caganhatapci.orbeon.services

import android.util.Log
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions

/**
 * Destekçi kaydı: kim, hangi adla, ne aldı.
 *
 * Amacı muhasebe değil — sonradan o kişilere hediye premium ya da kod
 * gönderebilmek. Belge kimliği playerId; ürünler diziye eklenir, aynı kişi
 * ikinci kez alırsa satır çoğalmaz. iOS ile AYNI koleksiyon.
 *
 * Güvenlik kuralları bu koleksiyonda istemciye okumayı kapatır: oyuncu adları
 * ve satın alma geçmişi yalnızca Firebase konsolundan görülür.
 */
object Supporters {

    private const val TAG = "Orbeon.Supporters"

    fun record(playerId: String, username: String, productId: String, price: String) {
        val db = runCatching { FirebaseFirestore.getInstance() }.getOrNull() ?: return
        val data = mutableMapOf<String, Any>(
            "products" to FieldValue.arrayUnion(productId),
            "lastPurchaseAt" to FieldValue.serverTimestamp(),
            "purchaseCount" to FieldValue.increment(1)
        )
        if (username.isNotEmpty()) data["username"] = username
        if (price.isNotEmpty()) data["lastPrice"] = price

        db.collection("supporters").document(playerId)
            .set(data, SetOptions.merge())
            .addOnSuccessListener { Log.i(TAG, "Destekçi kaydedildi: $playerId ← $productId") }
            .addOnFailureListener { Log.e(TAG, "Destekçi yazılamadı $playerId: ${it.message}") }
    }
}
