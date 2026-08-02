package com.caganhatapci.orbeon.services

import android.app.Activity
import android.content.Context
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.interstitial.InterstitialAd
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import com.caganhatapci.orbeon.BuildConfig
import com.caganhatapci.orbeon.model.LevelLibrary

/**
 * Reklam politikası — oyuncuya saygılı, net kurallar:
 *  • İlk 10 bölümde ASLA reklam gösterilmez (yeni oyuncu deneyimi kutsaldır).
 *  • 11. bölümden itibaren: her 2 bölüm tamamlamada 1 geçiş reklamı.
 *  • Sonsuz modda: her 3 oyun sonunda 1 geçiş reklamı.
 *  • Premium alındıysa hiçbir zaman reklam gösterilmez.
 *  • Banner reklam yoktur — oyun alanı her zaman temizdir.
 *  • Ödüllü reklam yalnızca oyuncu isterse oynar.
 */
class AdsManager(private val context: Context) {

    companion object {
        const val INTERSTITIAL_EVERY_N_COMPLETIONS = 2
        const val INTERSTITIAL_EVERY_N_ENDLESS_RUNS = 3
        private const val NUDGE_EVERY_N_ADS = 3
        private const val TAG = "Orbeon.Ads"

        // DEBUG'da Google'ın resmi TEST birimleri kullanılır: geliştirme
        // sırasında kendi reklamına tıklamak AdMob hesabını kapattırabilir.
        //
        // TODO: Aşağıdaki RELEASE birimleri iOS uygulamasına aittir. AdMob'da
        // Android uygulamasını oluşturduktan sonra ona ait geçiş ve ödüllü
        // birimleri üret ve buradaki kimlikleri onlarla değiştir; iOS birimleri
        // Android'de reklam döndürmez.
        private val INTERSTITIAL_UNIT = if (BuildConfig.DEBUG)
            "ca-app-pub-3940256099942544/1033173712"
        else
            "ca-app-pub-2696377554654488/4128883047"

        private val REWARDED_UNIT = if (BuildConfig.DEBUG)
            "ca-app-pub-3940256099942544/5224354917"
        else
            "ca-app-pub-2696377554654488/9121540024"
    }

    enum class Nudge { PREMIUM, SUPPORT }
    enum class RewardNotice { UNAVAILABLE, NOT_EARNED }

    /**
     * Reklam kapandıktan sonra ara sıra (her 3 reklamda bir) nazik bir
     * hatırlatma çıkar; sırayla biri Premium, biri "Destek Ol".
     */
    var nudge by mutableStateOf<Nudge?>(null)
    var rewardNotice by mutableStateOf<RewardNotice?>(null)
    var rewardedReady by mutableStateOf(false)
        private set

    private var interstitial: InterstitialAd? = null
    private var rewarded: RewardedAd? = null
    private var adsShownCount = 0
    private var nudgeShowsSupport = false
    private var completionsSinceAd = 0
    private var endlessRunsSinceAd = 0
    private var started = false

    /** Onay akışı bittikten SONRA çağrılır; öncesinde reklam istemek anlamsız. */
    fun start() {
        if (started) return
        started = true
        MobileAds.initialize(context) { }
        preloadInterstitial()
        preloadRewarded()
    }

    private fun preloadInterstitial() {
        InterstitialAd.load(context, INTERSTITIAL_UNIT, AdRequest.Builder().build(),
            object : InterstitialAdLoadCallback() {
                override fun onAdLoaded(ad: InterstitialAd) { interstitial = ad }
                override fun onAdFailedToLoad(error: LoadAdError) {
                    // Logcat'te "Orbeon.Ads" ile filtrelenip görülebilir —
                    // reklam gelmeme sebebini (doldurulamadı/ağ) gösterir
                    Log.e(TAG, "Geçiş reklamı yüklenemedi: ${error.message}")
                    interstitial = null
                }
            })
    }

    private fun preloadRewarded() {
        RewardedAd.load(context, REWARDED_UNIT, AdRequest.Builder().build(),
            object : RewardedAdLoadCallback() {
                override fun onAdLoaded(ad: RewardedAd) { rewarded = ad; rewardedReady = true }
                override fun onAdFailedToLoad(error: LoadAdError) {
                    Log.e(TAG, "Ödüllü reklam yüklenemedi: ${error.message}")
                    rewarded = null
                    rewardedReady = false
                }
            })
    }

    /** Bölüm tamamlandığında çağrılır; reklam kapanınca `onDone` çalışır. */
    fun levelCompleted(activity: Activity, level: Int, isPremium: Boolean, onDone: () -> Unit) {
        // İlk 10 bölüm HER ZAMAN reklamsızdır — Premium'da da hiç reklam yok.
        if (isPremium || level <= LevelLibrary.AD_FREE_LEVELS) { onDone(); return }
        completionsSinceAd++
        if (completionsSinceAd < INTERSTITIAL_EVERY_N_COMPLETIONS) { onDone(); return }
        completionsSinceAd = 0
        showInterstitial(activity, onDone)
    }

    /** Sonsuz mod oyunu bittiğinde çağrılır. */
    fun endlessEnded(activity: Activity, isPremium: Boolean, endlessUnlocked: Boolean, onDone: () -> Unit) {
        if (isPremium || !endlessUnlocked) { onDone(); return }
        endlessRunsSinceAd++
        if (endlessRunsSinceAd < INTERSTITIAL_EVERY_N_ENDLESS_RUNS) { onDone(); return }
        endlessRunsSinceAd = 0
        showInterstitial(activity, onDone)
    }

    private fun showInterstitial(activity: Activity, onDone: () -> Unit) {
        val ad = interstitial
        if (ad == null) { preloadInterstitial(); onDone(); return }
        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() {
                interstitial = null
                preloadInterstitial()
                adDismissed()
                onDone()
            }
            override fun onAdFailedToShowFullScreenContent(error: AdError) {
                interstitial = null
                preloadInterstitial()
                onDone()
            }
        }
        ad.show(activity)
    }

    /**
     * Ödüllü reklam gösterir. Ödül yalnızca reklam sonuna kadar izlenirse
     * verilir. Elde reklam yoksa istem çıkmaz; durum `rewardNotice` ile
     * bildirilir — düğmenin sessizce hiçbir şey yapmaması yerine.
     */
    fun showRewarded(activity: Activity, granted: (Boolean) -> Unit) {
        rewardNotice = null
        val ad = rewarded
        if (ad == null) {
            preloadRewarded()
            rewardNotice = RewardNotice.UNAVAILABLE
            granted(false)
            return
        }
        var earned = false
        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() {
                rewarded = null
                rewardedReady = false
                preloadRewarded()
                if (!earned) rewardNotice = RewardNotice.NOT_EARNED
                granted(earned)
            }
            override fun onAdFailedToShowFullScreenContent(error: AdError) {
                rewarded = null
                rewardedReady = false
                preloadRewarded()
                rewardNotice = RewardNotice.UNAVAILABLE
                granted(false)
            }
        }
        ad.show(activity) { earned = true }
    }

    /** Her 3 reklamda bir hatırlatmayı tetikler (Premium ↔ Destek sırayla). */
    private fun adDismissed() {
        adsShownCount++
        if (adsShownCount % NUDGE_EVERY_N_ADS == 0) {
            nudge = if (nudgeShowsSupport) Nudge.SUPPORT else Nudge.PREMIUM
            nudgeShowsSupport = !nudgeShowsSupport
        }
    }

    fun dismissNudge() { nudge = null }
    fun dismissRewardNotice() { rewardNotice = null }
}
