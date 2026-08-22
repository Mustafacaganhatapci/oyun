package com.caganhatapci.orbeon.services

import android.app.Activity
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
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
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.min
import kotlin.math.sin

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
 *
 * Eskiden ToneGenerator kullanıyorduk ama onun ton listesi sabit frekanslıdır:
 * kombo bir yerden sonra tizleşemiyor, "atlama sesi sabit kaldı" diye
 * duyuluyordu. Artık iOS'taki gibi kendi PCM tamponlarımızı sentezliyoruz —
 * pentatonik dizi üç oktava kadar çıkıyor ve tepeye varınca son beş nota
 * dönerek yükselme hissi sürüyor.
 */
class AudioEngine(context: Context) {
    private val sampleRate = 44100

    /** A minör pentatonik, üç oktav — kombo yükseldikçe sırayla çıkılır. */
    private val pluckScale = doubleArrayOf(
        220.0, 261.63, 293.66, 329.63, 392.0,
        440.0, 523.25, 587.33, 659.25, 783.99,
        880.0, 1046.50, 1174.66, 1318.51, 1567.98, 1760.0
    )
    /** Dizi bittiğinde tekrarlanan tepe nota sayısı */
    private val pluckTopCycle = 5

    private val plucks: List<ShortArray> by lazy { pluckScale.map { pluck(it) } }
    private val collectBuf: ShortArray by lazy { pluck(1046.50, 0.16) }
    private val tapBuf: ShortArray by lazy { pluck(587.33, 0.08, 0.35) }
    private val winBuf: ShortArray by lazy { chord(doubleArrayOf(523.25, 659.25, 783.99), 0.55) }
    private val failBuf: ShortArray by lazy { sweep(330.0, 110.0, 0.5) }
    /** Can eksilme sesi ölümden ayrı: düşen ikili + boğuk bir vuruş */
    private val lifeLostBuf: ShortArray by lazy { lifeLost() }

    /** Üst üste binen sesler için küçük bir AudioTrack havuzu */
    private val voices = arrayOfNulls<AudioTrack>(8)
    private val freeAt = LongArray(8)
    var soundEnabled = true
    var musicEnabled = true

    private val attrs = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_GAME)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()
    private val format = AudioFormat.Builder()
        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
        .setSampleRate(sampleRate)
        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
        .build()

    private fun play(buf: ShortArray) {
        if (!soundEnabled || buf.isEmpty()) return
        val now = System.currentTimeMillis()
        val ms = buf.size * 1000L / sampleRate
        var i = voices.indices.firstOrNull { freeAt[it] <= now }
        if (i == null) i = voices.indices.minByOrNull { freeAt[it] } ?: 0
        freeAt[i] = now + ms
        runCatching {
            voices[i]?.let { it.stop(); it.release() }
            val track = AudioTrack(
                attrs, format, buf.size * 2,
                AudioTrack.MODE_STATIC, AudioManager.AUDIO_SESSION_ID_GENERATE
            )
            track.write(buf, 0, buf.size)
            track.play()
            voices[i] = track
        }
    }

    /** Kombo yükseldikçe ton tizleşir — ilerleme kulakla da hissedilir. */
    fun playHop(combo: Int) {
        val count = plucks.size
        var index = (combo - 1).coerceAtLeast(0)
        if (index >= count) {
            val cycle = min(pluckTopCycle, count)
            index = count - cycle + (index - count) % cycle
        }
        play(plucks[index])
    }

    fun playCollect() = play(collectBuf)
    fun playWin() = play(winBuf)
    fun playFail() = play(failBuf)
    fun playLifeLost() = play(lifeLostBuf)
    fun playTap() = play(tapBuf)

    fun release() {
        voices.indices.forEach { i ->
            runCatching { voices[i]?.stop(); voices[i]?.release() }
            voices[i] = null
        }
    }

    // MARK: sentez

    /** Yumuşak inişli tek nota (iOS'taki pluck'ın karşılığı) */
    private fun pluck(freq: Double, seconds: Double = 0.22, gain: Double = 0.5): ShortArray {
        val n = (sampleRate * seconds).toInt()
        val out = ShortArray(n)
        for (i in 0 until n) {
            val t = i.toDouble() / sampleRate
            val env = exp(-t * 9.0) * fadeIn(i, n)
            val s = sin(2.0 * PI * freq * t) + 0.25 * sin(4.0 * PI * freq * t)
            out[i] = clip(s * env * gain)
        }
        return out
    }

    private fun chord(freqs: DoubleArray, seconds: Double): ShortArray {
        val n = (sampleRate * seconds).toInt()
        val out = ShortArray(n)
        for (i in 0 until n) {
            val t = i.toDouble() / sampleRate
            val env = exp(-t * 3.2) * fadeIn(i, n)
            var s = 0.0
            freqs.forEach { s += sin(2.0 * PI * it * t) }
            out[i] = clip(s / freqs.size * env * 0.55)
        }
        return out
    }

    private fun sweep(from: Double, to: Double, seconds: Double): ShortArray {
        val n = (sampleRate * seconds).toInt()
        val out = ShortArray(n)
        var phase = 0.0
        for (i in 0 until n) {
            val p = i.toDouble() / n
            val f = from + (to - from) * p
            phase += 2.0 * PI * f / sampleRate
            val env = (1.0 - p) * fadeIn(i, n)
            out[i] = clip(sin(phase) * env * 0.5)
        }
        return out
    }

    /** Ölüm sesinden ayrışsın diye: E5→B4 düşen ikili + 110 Hz boğuk vuruş */
    private fun lifeLost(): ShortArray {
        val seconds = 0.42
        val n = (sampleRate * seconds).toInt()
        val out = ShortArray(n)
        for (i in 0 until n) {
            val t = i.toDouble() / sampleRate
            var s = 0.0
            if (t < 0.16) s += sin(2.0 * PI * 659.25 * t) * exp(-t * 12.0)
            if (t >= 0.10) {
                val u = t - 0.10
                s += sin(2.0 * PI * 493.88 * u) * exp(-u * 9.0)
            }
            s += sin(2.0 * PI * 110.0 * t) * exp(-t * 6.0) * 0.6
            out[i] = clip(s * 0.42 * fadeIn(i, n))
        }
        return out
    }

    /** İlk milisaniyelerde tık sesi olmasın diye kısa bir açılış rampası */
    private fun fadeIn(i: Int, n: Int): Double {
        val ramp = 64
        return if (i < ramp) i.toDouble() / ramp else 1.0
    }

    private fun clip(v: Double): Short =
        (v.coerceIn(-1.0, 1.0) * Short.MAX_VALUE).toInt().toShort()
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
