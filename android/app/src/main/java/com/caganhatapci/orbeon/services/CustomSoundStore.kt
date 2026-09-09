package com.caganhatapci.orbeon.services

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import android.os.Handler
import android.os.Looper
import com.caganhatapci.orbeon.store.prefs
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import kotlin.concurrent.thread
import kotlin.math.abs
import kotlin.math.min

/**
 * Premium oyuncunun kendi sesiyle değiştirebildiği efekt yuvaları.
 * Atlayış sesi ayrı ele alınır: kayıt, kombo yükseldikçe hızlandırılıp
 * inceltilir — sentetik pentatonik dizinin yaptığını oyuncunun kendi sesi yapar.
 */
enum class CustomSoundSlot(val key: String, val maxMs: Int) {
    HOP("hop", 900),
    COLLECT("collect", 900),
    /**
     * Kapı açılma sesi. Bölüm bitirme sesinden AYRI bir yuva: ikisi aynıyken
     * oyuncu son yıldızı toplayınca bölümü bitirdiğini sanıyordu.
     */
    GATE("gate", 2000),
    LIFE_LOST("life_lost", 2000),
    FAIL("fail", 2000),
    WIN("win", 2000)
}

/**
 * Kayıtları cihazda tutar ve ses motoruna hazır PCM olarak verir.
 * Kayıtlar hiçbir yere yüklenmez.
 */
class CustomSoundStore(private val context: Context) {
    private val sampleRate = 44100

    /** Kaydı olan yuvalar */
    var recorded by mutableStateOf<Set<CustomSoundSlot>>(emptySet())
        private set
    /** Şu an kayıt alınan yuva */
    var recording by mutableStateOf<CustomSoundSlot?>(null)
        private set
    /**
     * Geri sayımı süren yuva. Mikrofona basınca kayıt HEMEN başlamıyor:
     * üçten geri sayılıyor. Aksi hâlde kaydın ilk yarısı, telefonu ağzına
     * götürürkenki hışırtı oluyordu.
     */
    var arming by mutableStateOf<CustomSoundSlot?>(null)
        private set
    /** Geri sayımda kalan saniye (3 → 2 → 1); kayıt dışında 0 */
    var countdown by mutableIntStateOf(0)
        private set
    /** Kayıtlar oyunda kullanılsın mı */
    var enabled by mutableStateOf(prefs(context).getBoolean(KEY_ENABLED, true))
        private set

    /** Faturalandırmadan beslenir; premium bitince kayıtlar devre dışı kalır */
    var premiumActive = false

    private var recordJob: Thread? = null
    /** Geri sayım adımları; vazgeçilirse hepsi birden iptal edilir */
    private val armHandler = Handler(Looper.getMainLooper())
    @Volatile private var stopRequested = false
    private var audio: AudioEngine? = null

    private val folder: File
        get() = File(context.filesDir, "customsfx").apply { if (!exists()) mkdirs() }

    private fun file(slot: CustomSoundSlot) = File(folder, "${slot.key}.pcm")

    init { refreshRecorded() }

    private fun refreshRecorded() {
        recorded = CustomSoundSlot.entries.filter { file(it).exists() }.toSet()
    }

    fun hasRecording(slot: CustomSoundSlot) = file(slot).exists()

    fun updateEnabled(value: Boolean) {
        enabled = value
        prefs(context).edit().putBoolean(KEY_ENABLED, value).apply()
        audio?.let { applyToEngine(it) }
    }

    fun hasMicPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    // MARK: Kayıt

    /**
     * 3 → 2 → 1 → kayıt. Her adımda kısa bir tık çalar; ekrana bakmadan da
     * ne zaman başlayacağı belli olsun diye.
     */
    fun startRecording(slot: CustomSoundSlot) {
        if (recording != null || arming != null || !hasMicPermission()) return
        arming = slot
        countdown = 3
        // İlk tıkı çağıran ekran çaldı; buradan bir daha çalmak çift ses olur
        for (step in 1..3) {
            armHandler.postDelayed({
                if (arming != slot) return@postDelayed
                val left = 3 - step
                countdown = left
                if (left > 0) {
                    audio?.playTap()
                } else {
                    arming = null
                    beginRecording(slot)
                }
            }, TICK_MS * step)
        }
    }

    /** Geri sayarken vazgeçildi */
    fun cancelArming() {
        armHandler.removeCallbacksAndMessages(null)
        arming = null
        countdown = 0
    }

    /**
     * Ham PCM yakalar. Süre dolunca kendiliğinden durur — uzun kayıt zaten
     * atlayış sesi olarak işe yaramıyor.
     */
    private fun beginRecording(slot: CustomSoundSlot) {
        countdown = 0
        val minBuf = AudioRecord.getMinBufferSize(
            sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuf <= 0) return

        val maxSamples = sampleRate * slot.maxMs / 1000
        stopRequested = false
        recording = slot

        recordJob = thread(start = true) {
            val rec = runCatching {
                @Suppress("MissingPermission")
                AudioRecord(
                    MediaRecorder.AudioSource.MIC, sampleRate,
                    AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
                    minBuf * 2
                )
            }.getOrNull()
            if (rec == null || rec.state != AudioRecord.STATE_INITIALIZED) {
                runCatching { rec?.release() }
                onMain { recording = null }
                return@thread
            }
            val out = ShortArray(maxSamples)
            var written = 0
            runCatching {
                rec.startRecording()
                val chunk = ShortArray(minBuf)
                while (!stopRequested && written < maxSamples) {
                    val n = rec.read(chunk, 0, min(chunk.size, maxSamples - written))
                    if (n <= 0) break
                    System.arraycopy(chunk, 0, out, written, n)
                    written += n
                }
            }
            runCatching { rec.stop() }
            runCatching { rec.release() }

            val clean = clean(out.copyOf(written))
            if (clean != null) save(slot, clean) else file(slot).delete()
            onMain {
                recording = null
                refreshRecorded()
                audio?.let { applyToEngine(it) }
            }
        }
    }

    /** Compose durumu yalnızca ana iş parçacığından yazılsın */
    private fun onMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block()
        else Handler(Looper.getMainLooper()).post(block)
    }

    fun stopRecording() {
        // Geri sayarken "durdur"a basılırsa kayıt hiç başlamasın
        cancelArming()
        stopRequested = true
        recordJob = null
    }

    fun delete(slot: CustomSoundSlot) {
        file(slot).delete()
        refreshRecorded()
        audio?.let { applyToEngine(it) }
    }

    fun preview(slot: CustomSoundSlot, engine: AudioEngine) {
        load(slot)?.let { engine.playPreview(it) }
    }

    // MARK: Motora aktarma

    /**
     * Kayıtları (premium ve açıksa) motora yükler. Premium biterse motordaki
     * tamponlar boşaltılır ama dosyalar diskte kalır.
     */
    fun applyToEngine(engine: AudioEngine) {
        audio = engine
        if (!premiumActive || !enabled) {
            engine.clearCustomSounds()
            return
        }
        engine.applyCustomSounds(
            hop = load(CustomSoundSlot.HOP)?.let { engine.pitchLadder(it) } ?: emptyList(),
            collect = load(CustomSoundSlot.COLLECT),
            gate = load(CustomSoundSlot.GATE),
            lifeLost = load(CustomSoundSlot.LIFE_LOST),
            fail = load(CustomSoundSlot.FAIL),
            win = load(CustomSoundSlot.WIN)
        )
    }

    // MARK: Dosya + temizlik

    private fun save(slot: CustomSoundSlot, data: ShortArray) {
        runCatching {
            DataOutputStream(file(slot).outputStream().buffered()).use { out ->
                out.writeInt(data.size)
                data.forEach { out.writeShort(it.toInt()) }
            }
        }
    }

    private fun load(slot: CustomSoundSlot): ShortArray? {
        val f = file(slot)
        if (!f.exists()) return null
        return runCatching {
            DataInputStream(f.inputStream().buffered()).use { input ->
                val n = input.readInt()
                if (n <= 0 || n > sampleRate * 4) return@use null
                ShortArray(n) { input.readShort() }
            }
        }.getOrNull()
    }

    /**
     * Sessiz baş/sonu kırpar, tepe seviyesini eşitler ve uçlara kısa bir
     * yumuşatma koyar — ham kayıtta tık ve boşluk çok belirgin oluyor.
     */
    private fun clean(input: ShortArray): ShortArray? {
        val threshold = (Short.MAX_VALUE * 0.02).toInt()
        var start = 0
        while (start < input.size && abs(input[start].toInt()) < threshold) start++
        var end = input.size - 1
        while (end > start && abs(input[end].toInt()) < threshold) end--
        if (end <= start + 64) return null

        val out = input.copyOfRange(start, end + 1)
        val peak = out.maxOf { abs(it.toInt()) }
        if (peak > 8) {
            val gain = Short.MAX_VALUE * 0.85 / peak
            for (i in out.indices) {
                out[i] = (out[i] * gain).toInt().coerceIn(-32768, 32767).toShort()
            }
        }
        val ramp = min(256, out.size / 4)
        for (i in 0 until ramp) {
            val g = i.toDouble() / ramp
            out[i] = (out[i] * g).toInt().toShort()
            val j = out.size - 1 - i
            out[j] = (out[j] * g).toInt().toShort()
        }
        return out
    }

    private companion object {
        const val KEY_ENABLED = "customSoundsEnabled"
        /** Geri sayım adımı. iOS'takiyle aynı: 0,8 sn */
        const val TICK_MS = 800L
    }
}
