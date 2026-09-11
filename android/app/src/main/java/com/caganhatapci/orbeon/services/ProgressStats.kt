package com.caganhatapci.orbeon.services

import android.content.Context
import com.caganhatapci.orbeon.model.LevelLibrary
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore

/**
 * "İnsanlar en fazla hangi bölüme kadar gelmiş?" — iOS'taki `ProgressStats`'in
 * karşılığı.
 *
 * Bu soruya bugüne kadar cevap veremiyorduk. Sıralama yalnızca sonsuz mod ve
 * hız turunu tutuyor, kampanya ilerlemesi hiçbir yere yazılmıyordu; yani
 * oyuncuların oyunu nerede bıraktığı görülmüyordu. Bir bölüm çok zorsa, bir
 * bölüm bozuksa ya da insanlar 12'de toptan gidiyorsa bunu ancak birinin yazıp
 * söylemesiyle öğrenebilirdik.
 *
 * Toplanan şey bir SAYAÇ, bir kayıt değil: "kaç kişi bu bölümü bitirdi". Kim
 * olduğu yazılmıyor, yazılamıyor da — `FieldValue.increment` sayıyı okumadan
 * bir artırıyor, belge de istemciye kapalı. Panoyu yalnızca Firebase
 * konsolundan görüyoruz.
 *
 * Her bölüm CİHAZ BAŞINA BİR KEZ sayılıyor. Aynı bölümü on kez oynayan biri
 * eğriyi on kat bozmamalı; ölçmek istediğimiz "kaç kişi buraya geldi", "kaç
 * kez oynandı" değil.
 *
 * Belge iOS'unkinden AYRI (`progress_android`): iki platformun eğrisi farklı
 * olabilir ve tek belgeye yazmak ikisini birbirine karıştırırdı. Ayrıca tek
 * bir Firestore belgesi saniyede ~1 yazma kaldırıyor; ikiye bölmek o sınırı da
 * ikiye bölüyor.
 */
object ProgressStats {

    private const val KEY = "stats.reportedLevel"

    /**
     * Bölüm bitirildiğinde çağrılır.
     *
     * Yalnızca ÖNCEKİ EN YÜKSEKTEN büyük olanlar bildiriliyor: eski bir bölüme
     * dönüp tekrar oynamak sayacı ikinci kez artırmıyor. Ardışık oynandığı
     * için atlanan bölüm de olmuyor.
     */
    fun reportCompleted(context: Context, level: Int) {
        if (level <= 0 || level == LevelLibrary.TUTORIAL_ID) return
        val p = context.getSharedPreferences("orbeon", Context.MODE_PRIVATE)
        if (level <= p.getInt(KEY, 0)) return
        p.edit().putInt(KEY, level).apply()

        // Alan adı üç haneye tamamlanıyor (`lvl_007`) çünkü konsol alanları
        // metin olarak sıralıyor: sıfırsız yazılsa 10, 2'den önce gelirdi.
        val field = "lvl_%03d".format(level)
        runCatching {
            FirebaseFirestore.getInstance()
                .collection("stats").document("progress_android")
                .set(mapOf(field to FieldValue.increment(1)), com.google.firebase.firestore.SetOptions.merge())
        }
        // Sessiz: bu bir istatistik, oyuncunun oyununu etkilemiyor
    }
}
