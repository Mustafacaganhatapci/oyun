package com.caganhatapci.orbeon.services

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.google.firebase.messaging.FirebaseMessaging
import java.util.Locale
import java.util.concurrent.TimeUnit

/**
 * Bildirimler — iOS'taki `PushManager`'ın karşılığı.
 *
 * ÜÇ KANAL var ve ikisi hiçbir kurulum istemiyor:
 *
 *  1. **Haftalık yarış hatırlatması** — yerel, sıralama sıfırlanmadan bir gün
 *     önce, WorkManager ile. Sunucu da APNs/FCM anahtarı da gerekmiyor.
 *  2. **Yeni sürüm hatırlatması** — yerel, duyuru belgesi yayındaysa birkaç
 *     saat sonra düşüyor.
 *  3. **Uzaktan yayın** — Firebase konsolundan konuya gönderi. Bu, projede
 *     `firebase-messaging` bağlı olduğu sürece çalışıyor.
 *
 * İZİN AÇILIŞTA İSTENMİYOR. Oyuncu ayarlardan açtığı an isteniyor: oyunu ilk
 * kez açan birinin karşısına çıkan izin kutusu çoğunlukla reddediliyor.
 * Android 13'ten önce bildirim izni diye bir şey yok, orada anahtar doğrudan
 * çalışıyor.
 */
class PushManager(private val context: Context) {

    companion object {
        const val CHANNEL_ID = "orbeon.general"
        private const val ENABLED_KEY = "push.enabled"
        private const val TOPIC = "all"

        /** Uygulamanın konuştuğu diller */
        private val LANGUAGES = listOf("tr", "en", "de", "es", "fr", "ja")

        private const val RACE_WORK = "orbeon.reminder.race"
        private const val UPDATE_WORK = "orbeon.reminder.update"
        private const val TAG = "Orbeon.Push"

        /**
         * Cihazın dil konusu — `all_tr`, `all_en` gibi.
         *
         * Bir konu yayını TEK metin gönderiyor ve cihazın diline göre
         * değişmiyor; Firebase'in dile göre hedeflemesi ise Analytics istiyor
         * ve o bağlı değil. Her cihaz hem `all`'a hem kendi dilinin konusuna
         * abone oluyor: Türkçe metni `all_tr`'ye, İngilizceyi `all_en`'e
         * gönderiyorsun. Desteklenmeyen bir dil `all_en`'e düşüyor, çünkü
         * uygulamanın kendisi de o durumda İngilizce açılıyor.
         */
        private fun languageTopic(): String {
            val code = Locale.getDefault().language.lowercase()
            return "all_" + if (LANGUAGES.contains(code)) code else "en"
        }
    }

    private val p = context.getSharedPreferences("orbeon", Context.MODE_PRIVATE)

    var isEnabled by mutableStateOf(p.getBoolean(ENABLED_KEY, false))
        private set

    /** Android 13+ izni reddedildi: ayarlarda sistem ayarlarına yol gösteriliyor */
    var isDenied by mutableStateOf(false)
        private set

    init { ensureChannel() }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Orbeon", NotificationManager.IMPORTANCE_DEFAULT)
        )
    }

    /** Android 13+ bildirim izni verilmiş mi */
    fun hasSystemPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    /**
     * Açılışta çağrılır. İZİN İSTEMEZ; yalnızca daha önce açmış olanın
     * aboneliğini ve hatırlatmalarını tazeler. Sistem izni sonradan
     * kapatılmışsa anahtar da kapalıya çekiliyor — açık görünüp hiçbir şey
     * gelmemesi, kapalı görünmesinden daha kafa karıştırıcı.
     */
    fun restoreIfEnabled() {
        if (!isEnabled) return
        if (!hasSystemPermission()) {
            setStored(false)
            cancelReminders()
            return
        }
        subscribe()
        scheduleWeeklyRaceReminder()
    }

    /**
     * Ayarlardaki anahtar buraya bağlı. `granted`, Android 13+ izin kutusunun
     * sonucu; daha eski sürümlerde her zaman true.
     */
    fun setEnabled(on: Boolean, granted: Boolean = true) {
        if (!on) {
            unsubscribe()
            cancelReminders()
            setStored(false)
            return
        }
        if (!granted) {
            isDenied = true
            setStored(false)
            return
        }
        isDenied = false
        subscribe()
        scheduleWeeklyRaceReminder()
        setStored(true)
    }

    private fun setStored(value: Boolean) {
        isEnabled = value
        p.edit().putBoolean(ENABLED_KEY, value).apply()
    }

    // MARK: Uzaktan yayın

    private fun subscribe() {
        runCatching {
            FirebaseMessaging.getInstance().subscribeToTopic(TOPIC)
            FirebaseMessaging.getInstance().subscribeToTopic(languageTopic())
        }.onFailure { Log.w(TAG, "Konuya abone olunamadı: ${it.message}") }
    }

    private fun unsubscribe() {
        runCatching {
            FirebaseMessaging.getInstance().unsubscribeFromTopic(TOPIC)
            // Dil konularının HEPSİNDEN çıkılıyor, yalnızca şu ankinden değil:
            // oyuncu telefonun dilini değiştirmiş olabilir ve geride kalan bir
            // abonelik, bildirimleri kapatmış birine bildirim göndermek demek.
            for (code in LANGUAGES) {
                FirebaseMessaging.getInstance().unsubscribeFromTopic("all_$code")
            }
        }.onFailure { Log.w(TAG, "Abonelik bırakılamadı: ${it.message}") }
    }

    // MARK: Yerel hatırlatmalar

    /**
     * Haftalık yarış hatırlatması: sıralama sıfırlanmadan BİR GÜN önce, her
     * hafta tekrar ederek.
     *
     * Hafta tam yedi gün olduğu için ilk gecikmeyi bir kez hesaplamak yetiyor;
     * `PeriodicWorkRequest` sonrasını kendi taşıyor. `KEEP` değil `UPDATE`:
     * metin ya da saat değişmiş olabilir.
     */
    fun scheduleWeeklyRaceReminder() {
        val untilReset = LeaderboardService.secondsUntilReset()
        // Sıfırlanmaya bir günden az kaldıysa bu haftalık gönderi kaçtı;
        // bir sonraki haftanınkine kuruluyor.
        val week = 7L * 24 * 60 * 60
        var delay = untilReset - 24 * 60 * 60
        while (delay < 0) delay += week

        val request = PeriodicWorkRequestBuilder<ReminderWorker>(7, TimeUnit.DAYS)
            .setInitialDelay(delay, TimeUnit.SECONDS)
            .setInputData(workDataOf(ReminderWorker.KEY_KIND to ReminderWorker.KIND_RACE))
            .build()
        WorkManager.getInstance(context)
            .enqueueUniquePeriodicWork(RACE_WORK, ExistingPeriodicWorkPolicy.UPDATE, request)
    }

    /**
     * Yeni sürüm hatırlatması. Duyuru belgesi yayındaysa aynı metin birkaç saat
     * sonra bildirim olarak da düşüyor: kartı görüp "sonra" diyene ikinci bir
     * dokunuş. Duyuru artık geçerli değilse bekleyen iş iptal ediliyor —
     * güncellemeyi almış birine "güncelle" demek, hiç dememekten kötü.
     */
    fun syncUpdateReminder(title: String?, body: String?) {
        val manager = WorkManager.getInstance(context)
        if (!isEnabled || title.isNullOrBlank() || body.isNullOrBlank()) {
            manager.cancelUniqueWork(UPDATE_WORK)
            return
        }
        val request = OneTimeWorkRequestBuilder<ReminderWorker>()
            .setInitialDelay(4, TimeUnit.HOURS)
            .setInputData(
                workDataOf(
                    ReminderWorker.KEY_KIND to ReminderWorker.KIND_UPDATE,
                    ReminderWorker.KEY_TITLE to title,
                    ReminderWorker.KEY_BODY to body
                )
            )
            .build()
        manager.enqueueUniqueWork(UPDATE_WORK, ExistingWorkPolicy.REPLACE, request)
    }

    private fun cancelReminders() {
        val manager = WorkManager.getInstance(context)
        manager.cancelUniqueWork(RACE_WORK)
        manager.cancelUniqueWork(UPDATE_WORK)
    }
}
