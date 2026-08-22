package com.caganhatapci.orbeon

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.caganhatapci.orbeon.services.AdsManager
import com.caganhatapci.orbeon.services.AudioEngine
import com.caganhatapci.orbeon.services.BillingManager
import com.caganhatapci.orbeon.services.ConsentManager
import com.caganhatapci.orbeon.services.CustomSoundStore
import com.caganhatapci.orbeon.services.Haptics
import com.caganhatapci.orbeon.services.LeaderboardService
import com.caganhatapci.orbeon.store.DailyRewardStore
import com.caganhatapci.orbeon.store.MissionStore
import com.caganhatapci.orbeon.store.PlayerStore
import com.caganhatapci.orbeon.store.ProgressStore
import com.caganhatapci.orbeon.store.SettingsStore
import com.caganhatapci.orbeon.store.TutorialStore
import com.caganhatapci.orbeon.ui.RootScreen

/** Tüm ekranların paylaştığı uygulama durumu — iOS'taki EnvironmentObject'lerin karşılığı. */
class AppState(
    val progress: ProgressStore,
    val settings: SettingsStore,
    val player: PlayerStore,
    val daily: DailyRewardStore,
    val missions: MissionStore,
    val tutorial: TutorialStore,
    val billing: BillingManager,
    val ads: AdsManager,
    val consent: ConsentManager,
    val leaderboard: LeaderboardService,
    val audio: AudioEngine,
    val haptics: Haptics,
    val customSounds: CustomSoundStore
)

val LocalAppState = staticCompositionLocalOf<AppState> { error("AppState sağlanmadı") }
val LocalActivity = staticCompositionLocalOf<ComponentActivity> { error("Activity sağlanmadı") }

class MainActivity : ComponentActivity() {

    private lateinit var state: AppState

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        hideSystemBars()

        state = AppState(
            progress = ProgressStore(this),
            settings = SettingsStore(this),
            player = PlayerStore(this),
            daily = DailyRewardStore(this),
            missions = MissionStore(this),
            tutorial = TutorialStore(this),
            billing = BillingManager(this),
            ads = AdsManager(this),
            consent = ConsentManager(this),
            leaderboard = LeaderboardService(),
            audio = AudioEngine(this),
            haptics = Haptics(this),
            customSounds = CustomSoundStore(this)
        )

        state.audio.soundEnabled = state.settings.soundOn
        state.audio.musicEnabled = state.settings.musicOn
        state.haptics.enabled = state.settings.hapticsOn
        state.leaderboard.configureIfPossible()

        // Premium'un kendi kaydettiği sesler motora yüklenir (yoksa sentetik kalır)
        state.customSounds.premiumActive = state.billing.isPremium
        state.customSounds.applyToEngine(state.audio)

        // GDPR onayı önce; reklamlar ancak ondan sonra anlamlı
        state.consent.requestIfNeeded(this, state.billing.isPremium) {
            state.ads.start()
        }

        setContent {
            CompositionLocalProvider(
                LocalAppState provides state,
                LocalActivity provides this
            ) {
                RootScreen()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Uygulama açıkken gece yarısı geçilmiş olabilir
        state.daily.refresh()
        state.missions.reloadForToday()
        state.billing.refreshEntitlements()
        // Abonelik durumu değişmiş olabilir: kendi seslerin buna göre açılır/kapanır
        state.customSounds.premiumActive = state.billing.isPremium
        state.customSounds.applyToEngine(state.audio)
    }

    override fun onDestroy() {
        super.onDestroy()
        state.audio.release()
    }

    /** Oyun alanı bölünmesin diye sistem çubukları gizlenir. */
    private fun hideSystemBars() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val controller = WindowInsetsControllerCompat(window, window.decorView)
        controller.hide(WindowInsetsCompat.Type.systemBars())
        controller.systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
    }
}
