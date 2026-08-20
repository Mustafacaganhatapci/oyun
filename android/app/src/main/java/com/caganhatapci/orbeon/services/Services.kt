package com.caganhatapci.orbeon.services

import android.app.Activity
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.caganhatapci.orbeon.store.prefs
import com.google.android.play.core.review.ReviewManagerFactory
import com.google.android.ump.ConsentDebugSettings
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform
import kotlin.math.min

/**
 * GDPR onayı (Google UMP). Avrupa'daki kullanıcılara onay formunu gösterir.
 * Bu olmadan AdMob, EEA kullanıcılarına reklam sunmayı kısıtlar ve politika
 * ihlali sayar.
 *
 * Android'de ATT (iOS'taki izleme izni) yoktur; reklam kimliği kullanıcı
 * tarafından sistem ayarlarından yönetilir, ayrı bir istem gerekmez.
 * Premium kullanıcıya hiç reklam gösterilmediği için form da sorulmaz.
 */
class ConsentManager(private val context: Context) {

    var finished by mutableStateOf(false)
        private set

    private var started = false

    fun requestIfNeeded(activity: Activity, isPremium: Boolean, onFinished: () -> Unit) {
        if (started) return
        started = true
        if (isPremium) { finished = true; onFinished(); return }

        val params = ConsentRequestParameters.Builder()
            .setTagForUnderAgeOfConsent(false)
            .build()

        val info = UserMessagingPlatform.getConsentInformation(context)
        info.requestConsentInfoUpdate(activity, params, {
            UserMessagingPlatform.loadAndShowConsentFormIfRequired(activity) { error ->
                if (error != null) Log.e("Orbeon.Consent", "UMP form hatası: ${error.message}")
                finished = true
                onFinished()
            }
        }, { error ->
            Log.e("Orbeon.Consent", "UMP bilgi güncelleme hatası: ${error.message}")
            finished = true
            onFinished()
        })
    }
}

/**
 * Play Store değerlendirme istemi.
 *
 * Play istemi sınırlı sıklıkta gösterir ve ne zaman göstereceğine kendi karar
 * verir; bizim işimiz yalnızca DOĞRU ANI seçmek. En iyi an oyuncunun başarılı
 * hissettiği andır — 3/3 yıldızla bir bölüm bitirdiği an gibi. Kaybettiği ya
 * da reklam izlediği anda asla sormayız.
 */
object ReviewPrompt {
    private const val MINIMUM_COMPLETIONS = 8

    fun requestAfterGreatRun(activity: Activity, completedLevels: Int) {
        if (completedLevels < MINIMUM_COMPLETIONS) return

        val p = prefs(activity)
        val version = runCatching {
            activity.packageManager.getPackageInfo(activity.packageName, 0).versionName
        }.getOrNull() ?: "?"
        if (p.getString("review.lastPromptedVersion", null) == version) return
        p.edit().putString("review.lastPromptedVersion", version).apply()

        val manager = ReviewManagerFactory.create(activity)
        manager.requestReviewFlow().addOnCompleteListener { task ->
            if (task.isSuccessful) manager.launchReviewFlow(activity, task.result)
        }
    }
}

/**
 * Orbeon'un tüm sesi koddan üretilir — hiç ses dosyası yoktur.
 * ToneGenerator kısa, tiz tonlar için yeterlidir ve APK'yı büyütmez.
 */
class AudioEngine(context: Context) {
    /**
     * TEK bir ToneGenerator, çalarken gelen ikinci tonu yutuyor: hızlı bir
     * komboda atlayışların sesi düşüyor ve ses "tıkanmış" gibi duyuluyordu.
     * Küçük bir havuz, üst üste binen sesleri ayrı üreticilere dağıtıyor.
     */
    private val tones = mutableListOf<ToneGenerator>()
    /** Her üreticinin ne zaman boşalacağı (ms) — boş olanı seçmek için */
    private val freeAt = LongArray(4)
    var soundEnabled = true
    var musicEnabled = true

    init {
        repeat(4) {
            runCatching { ToneGenerator(AudioManager.STREAM_MUSIC, 70) }
                .getOrNull()?.let { tones.add(it) }
        }
    }

    private fun play(type: Int, ms: Int) {
        if (!soundEnabled || tones.isEmpty()) return
        val now = System.currentTimeMillis()
        // Boş üretici varsa onu kullan; yoksa en erken bitecek olanı ödünç al
        var i = (0 until tones.size).firstOrNull { freeAt[it] <= now }
        if (i == null) {
            i = (0 until tones.size).minByOrNull { freeAt[it] } ?: 0
            runCatching { tones[i].stopTone() }
        }
        freeAt[i] = now + ms
        runCatching { tones[i].startTone(type, ms) }
    }

    /** Kombo yükseldikçe ton tizleşir — ilerleme kulakla da hissedilir. */
    fun playHop(combo: Int) {
        val types = listOf(
            ToneGenerator.TONE_PROP_BEEP,
            ToneGenerator.TONE_DTMF_1, ToneGenerator.TONE_DTMF_3,
            ToneGenerator.TONE_DTMF_5, ToneGenerator.TONE_DTMF_7,
            ToneGenerator.TONE_DTMF_9
        )
        play(types[min(combo, types.size - 1)], 60)
    }

    fun playCollect() = play(ToneGenerator.TONE_PROP_ACK, 70)
    fun playWin() = play(ToneGenerator.TONE_PROP_BEEP2, 220)
    fun playFail() = play(ToneGenerator.TONE_SUP_ERROR, 200)
    fun playTap() = play(ToneGenerator.TONE_PROP_BEEP, 40)

    fun release() {
        tones.forEach { runCatching { it.release() } }
        tones.clear()
    }
}

/** Dokunsal geri bildirim. */
class Haptics(context: Context) {
    var enabled = true

    private val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    }

    private fun buzz(ms: Long, amplitude: Int) {
        if (!enabled) return
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        runCatching {
            v.vibrate(VibrationEffect.createOneShot(ms, amplitude))
        }
    }

    fun hop() = buzz(12, 60)
    fun collect() = buzz(18, 90)
    fun fail() = buzz(120, 200)
    fun win() = buzz(60, 160)
}
