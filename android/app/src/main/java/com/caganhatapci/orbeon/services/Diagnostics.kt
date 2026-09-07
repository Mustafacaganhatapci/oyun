package com.caganhatapci.orbeon.services

import com.google.firebase.crashlytics.FirebaseCrashlytics

/**
 * Çökme ve hata raporu — iOS'taki `Diagnostics`'in karşılığı.
 *
 * Bugüne kadar bir oyuncuda bir şey bozulduğunda haberimiz olmuyordu: log
 * yalnızca o cihazın kendisine yazılıyor, yani hatayı görmenin tek yolu o
 * telefonu elinde tutmaktı. Mağazadaki bir kullanıcının çökmesi ise hiçbir
 * yere düşmüyordu.
 *
 * Üç şey gidiyor:
 *  1. **Çökmeler** — yığın izi, cihaz, sürüm; gruplanmış hâlde
 *  2. **Ölümcül olmayan hatalar** — Firestore yazamadı, ürün yüklenemedi
 *     gibi. Uygulama çalışmaya devam ediyor ama bir şey yolunda gitmedi;
 *     bunlar toplanmadan hangi hatanın yaygın olduğu bilinemiyor.
 *  3. **Kimlik** — hangi oyuncuda olduğu. Firestore'daki `supporters` ve
 *     sıralama kayıtlarıyla aynı `playerId`; kişisel hiçbir şey taşımıyor,
 *     cihazda üretilmiş bir UUID.
 *
 * Her çağrı `runCatching` içinde: Crashlytics'in kendisi hata verirse oyun
 * çökmemeli — hata raporlayıcının yıktığı uygulama, raporlanacak hatadan
 * kötüdür.
 */
object Diagnostics {

    fun identify(playerId: String) {
        if (playerId.isBlank()) return
        runCatching { FirebaseCrashlytics.getInstance().setUserId(playerId) }
    }

    /**
     * Ölümcül olmayan hata. `domain` gruplama için: aynı alandan gelenler
     * panoda tek satırda toplanıyor, "üç kişide olmuş" ile "üç bin kişide
     * olmuş" ayırt edilebiliyor.
     */
    fun record(message: String, domain: String = "Orbeon") {
        runCatching {
            FirebaseCrashlytics.getInstance().recordException(Exception("[$domain] $message"))
        }
    }

    /**
     * Çökmenin ÖNCESİNDE ne olduğunu anlatan iz. Yığın izi nerede çöküldüğünü
     * söylüyor, bu da oraya nasıl gelindiğini.
     */
    fun breadcrumb(message: String) {
        runCatching { FirebaseCrashlytics.getInstance().log(message) }
    }
}
