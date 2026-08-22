package com.caganhatapci.orbeon.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.caganhatapci.orbeon.LocalActivity
import com.caganhatapci.orbeon.LocalAppState
import com.caganhatapci.orbeon.R
import com.caganhatapci.orbeon.game.GameEngine
import com.caganhatapci.orbeon.game.GameEvent
import com.caganhatapci.orbeon.game.GameMode
import com.caganhatapci.orbeon.model.LevelLibrary
import com.caganhatapci.orbeon.model.OrbStyle
import com.caganhatapci.orbeon.services.LeaderboardService
import com.caganhatapci.orbeon.services.ReviewPrompt
import com.caganhatapci.orbeon.store.OrbPhotoStore
import com.caganhatapci.orbeon.store.TutorialStore
import com.caganhatapci.orbeon.theme.Theme
import kotlinx.coroutines.delay

sealed class PlayMode {
    data class LevelPlay(val id: Int) : PlayMode()
    data object Endless : PlayMode()
    data object Speedrun : PlayMode()
}

private sealed class Overlay {
    data object None : Overlay()
    data object Paused : Overlay()
    data class Won(val stars: Int, val celebrationRes: Int?) : Overlay()
    data class EndlessOver(val score: Int) : Overlay()
    data class SpeedrunDone(val time: Double, val isRecord: Boolean) : Overlay()
}

/** Etkileşimli öğretici koçu — iOS'taki CoachStep'in karşılığı. */
private enum class Coach {
    HAZARD_INTRO, HAZARD_TIMING, HAZARD_CLEARED,   // kırmızı şerit: dondur → anlat → yaptır
    MOVING_INTRO, MOVING_TIMING,                    // hareketli halka
    TIMED_INTRO,                                    // süreli bölüm tanıtımı
    BOUNDS_INTRO;                                   // "kaçırmak artık elenmek"

    val isBlocking get() = this == HAZARD_INTRO || this == MOVING_INTRO ||
                           this == TIMED_INTRO || this == BOUNDS_INTRO
}

/** 3/3 yıldız için rastgele seçilen tebrik başlıkları */
private val CELEBRATIONS = listOf(
    R.string.celebrate_bravo, R.string.celebrate_perfect, R.string.celebrate_flawless,
    R.string.celebrate_spectacular, R.string.celebrate_legendary
)

@Composable
fun GameScreen(playMode: PlayMode, onExit: () -> Unit, onReplay: (PlayMode) -> Unit) {
    val app = LocalAppState.current
    val activity = LocalActivity.current
    val theme = app.settings.theme
    val orbStyle = OrbStyle.byId(app.settings.orbStyleId)
    val orbPhoto = remember {
        if (orbStyle.kind == OrbStyle.Kind.PHOTO) OrbPhotoStore.load(activity) else null
    }

    var speedIndex by remember { mutableIntStateOf(0) }
    var speedStart by remember { mutableStateOf(System.currentTimeMillis()) }
    var speedPenalty by remember { mutableStateOf(0.0) }

    // runId: aynı bölümü yeniden başlatmak motoru sıfırdan kurar (rota
    // değeri değişmediğinde bile) — "Tekrar Dene" ve "Restart" buna dayanır
    var runId by remember { mutableIntStateOf(0) }

    val currentLevelId = when (playMode) {
        is PlayMode.LevelPlay -> playMode.id
        PlayMode.Speedrun -> LevelLibrary.speedrunLevels[speedIndex]
        PlayMode.Endless -> null
    }
    val isTutorialLevel = currentLevelId == LevelLibrary.TUTORIAL_ID
    val isBonusLevel = currentLevelId?.let { LevelLibrary.isBonus(it) } == true
    // "Büyük yıldız" bölümlerinde 4, diğerlerinde 3 — kutlama ve yıldız
    // göstergeleri sabit 3 yerine buna bakar
    val maxStarsForLevel = currentLevelId?.let { LevelLibrary.maxStars(it) } ?: 3

    var overlay by remember { mutableStateOf<Overlay>(Overlay.None) }
    var coach by remember { mutableStateOf<Coach?>(null) }
    var lumenCount by remember { mutableIntStateOf(0) }
    var deathsThisLevel by remember { mutableIntStateOf(0) }
    var revivedThisRun by remember { mutableStateOf(false) }
    var endlessScore by remember { mutableIntStateOf(0) }
    var extraLives by remember { mutableIntStateOf(0) }
    // Yıldız eşiği geçilip açılan, henüz gösterilmemiş karakter
    var orbReveal by remember { mutableStateOf<OrbStyle?>(null) }
    // Sonsuz modda yeniden başlat onayı (skor sıfırdan büyükken sorulur)
    var confirmRestart by remember { mutableStateOf(false) }
    var bonusRemaining by remember { mutableIntStateOf(0) }
    var timeRemaining by remember { mutableIntStateOf(-1) }
    var tutorialHops by remember { mutableIntStateOf(0) }
    var levelIntroVisible by remember { mutableStateOf(false) }
    var frame by remember { mutableIntStateOf(0) }

    val engine = remember(currentLevelId, playMode, runId) {
        val mode = if (playMode == PlayMode.Endless) GameMode.Endless
                   else GameMode.LevelMode(currentLevelId ?: 1)
        GameEngine(
            mode,
            isPremium = app.billing.isPremium,
            requiresAllLumens = playMode == PlayMode.Speedrun
        )
    }

    // Yeni motor = yeni deneme: sayaçlar, bölüm kartı ve koç sıfırdan
    LaunchedEffect(engine) {
        lumenCount = 0
        deathsThisLevel = 0
        bonusRemaining = 0
        timeRemaining = -1
        tutorialHops = 0
        overlay = Overlay.None
        coach = null
        if (playMode == PlayMode.Endless) revivedThisRun = false
        extraLives = engine.extraLives

        if (currentLevelId != null && !isTutorialLevel) {
            levelIntroVisible = true
        }

        // İlk katı / ilk süreli bölüm: oyunu dondurup bir kez tanıt
        if (playMode is PlayMode.LevelPlay) {
            val id = playMode.id
            if (!LevelLibrary.isForgiving(id) && app.tutorial.shouldShow(TutorialStore.Step.BOUNDS)) {
                engine.coachFrozen = true
                coach = Coach.BOUNDS_INTRO
            } else if (LevelLibrary.hasTimer(id) && app.tutorial.shouldShow(TutorialStore.Step.TIMED)) {
                engine.coachFrozen = true
                coach = Coach.TIMED_INTRO
            }
        }
    }

    LaunchedEffect(levelIntroVisible) {
        if (levelIntroVisible) { delay(1600); levelIntroVisible = false }
    }

    // Koç "başardın" şeridi kısa süre görünüp kaybolur
    LaunchedEffect(coach) {
        if (coach == Coach.HAZARD_CLEARED) {
            delay(1800)
            if (coach == Coach.HAZARD_CLEARED) coach = null
        }
    }

    engine.onEvent = { event ->
        when (event) {
            is GameEvent.Hop -> {
                app.audio.playHop(event.combo)
                app.haptics.hop()
                app.progress.recordHop()
                app.missions.recordHops(1)
                if (isTutorialLevel) tutorialHops++
                // Oyuncu adımı gerçekten yapınca koç ilerler
                when (coach) {
                    Coach.HAZARD_TIMING -> {
                        coach = Coach.HAZARD_CLEARED
                        app.tutorial.markShown(TutorialStore.Step.HAZARD)
                    }
                    Coach.MOVING_TIMING -> {
                        coach = null
                        app.tutorial.markShown(TutorialStore.Step.MOVING)
                    }
                    else -> Unit
                }
            }
            is GameEvent.Attached -> {
                // Yeni mekanikli halkaya İLK kez konunca: dondur, öğret
                if (playMode is PlayMode.LevelPlay && coach == null) {
                    if (event.hasHazard && app.tutorial.shouldShow(TutorialStore.Step.HAZARD)) {
                        engine.coachFrozen = true
                        coach = Coach.HAZARD_INTRO
                    } else if (event.isMoving && app.tutorial.shouldShow(TutorialStore.Step.MOVING)) {
                        engine.coachFrozen = true
                        coach = Coach.MOVING_INTRO
                    }
                }
            }
            is GameEvent.Collect -> {
                lumenCount = event.total
                app.audio.playCollect()
                app.haptics.collect()
            }
            GameEvent.GateUnlocked -> {
                app.audio.playWin()
                app.haptics.win()
            }
            GameEvent.Fail -> {
                app.audio.playFail()
                app.haptics.fail()
                deathsThisLevel++
                if (playMode == PlayMode.Speedrun) speedPenalty += 2.0
            }
            is GameEvent.BonusTick -> bonusRemaining = event.remaining
            is GameEvent.TimeTick -> timeRemaining = event.remaining
            is GameEvent.EndlessScore -> endlessScore = event.score
            is GameEvent.ExtraLifeUsed -> {
                extraLives = event.remaining
                app.audio.playLifeLost()
                app.haptics.fail()
            }
            is GameEvent.EndlessGameOver -> {
                app.progress.recordEndless(event.score)
                if (app.player.hasUsername) {
                    app.leaderboard.submit(
                        LeaderboardService.Mode.ENDLESS, event.score.toDouble(),
                        app.player.username, app.player.playerId
                    )
                }
                app.audio.playFail()
                overlay = Overlay.EndlessOver(event.score)
            }
            is GameEvent.Win -> {
                app.audio.playWin()
                app.haptics.win()
                val celebration =
                    if (event.stars >= maxStarsForLevel && !isTutorialLevel) CELEBRATIONS.random() else null
                when (playMode) {
                    is PlayMode.LevelPlay -> {
                        val id = playMode.id
                        if (id == LevelLibrary.TUTORIAL_ID) {
                            app.tutorial.markShown(TutorialStore.Step.LAUNCH)
                            app.tutorial.markShown(TutorialStore.Step.GATE)
                        } else {
                            app.progress.complete(id, event.stars)
                            app.missions.recordLevelCleared(deathsThisLevel == 0, event.stars)
                            app.missions.recordLumens(lumenCount)
                            // Oyuncunun en iyi hissettiği an: kusursuz bir bölüm
                            if (event.stars >= maxStarsForLevel) {
                                ReviewPrompt.requestAfterGreatRun(activity, app.progress.completedCount)
                            }
                            // Bu bölümün yıldızları bir eşiği geçtiyse yeni
                            // karakter AÇILDIĞI ANDA gösterilsin; mağazada
                            // tesadüfen fark edilmeyi beklemek ödülü ödül
                            // olmaktan çıkarıyor.
                            orbReveal = app.progress.pendingOrbReveal()
                        }
                        overlay = Overlay.Won(event.stars, celebration)
                    }
                    PlayMode.Speedrun -> {
                        if (speedIndex < LevelLibrary.speedrunLevels.size - 1) {
                            speedIndex++
                            runId++   // sıradaki koşu bölümü kurulsun
                        } else {
                            val total = (System.currentTimeMillis() - speedStart) / 1000.0 + speedPenalty
                            val isRecord = app.progress.recordSpeedrun(total)
                            if (app.player.hasUsername) {
                                app.leaderboard.submit(
                                    LeaderboardService.Mode.SPEEDRUN, total,
                                    app.player.username, app.player.playerId
                                )
                            }
                            overlay = Overlay.SpeedrunDone(total, isRecord)
                        }
                    }
                    PlayMode.Endless -> Unit
                }
            }
        }
    }

    // Oyun döngüsü — ekran yenileme hızına kilitli
    LaunchedEffect(engine) {
        var last = 0L
        while (true) {
            withFrameNanos { now ->
                val dt = if (last == 0L) 1.0 / 60.0 else (now - last) / 1_000_000_000.0
                last = now
                if (overlay == Overlay.None) engine.update(dt)
                frame++
            }
        }
    }

    fun restart() {
        if (playMode == PlayMode.Speedrun) {
            speedIndex = 0
            speedStart = System.currentTimeMillis()
            speedPenalty = 0.0
        }
        runId++
    }

    ThemeBackground(theme) {
        Box(
            Modifier
                .fillMaxSize()
                .pointerInput(engine) {
                    detectTapGestures {
                        if (overlay == Overlay.None && coach?.isBlocking != true) engine.onTap()
                    }
                }
        ) {
            GameCanvas(engine, theme, orbStyle, orbPhoto, frame)
            GameHud(
                playMode = playMode,
                levelId = currentLevelId,
                lumenCount = lumenCount,
                endlessScore = endlessScore,
                bonusRemaining = bonusRemaining,
                timeRemaining = timeRemaining,
                extraLives = extraLives,
                theme = theme,
                onPause = { overlay = Overlay.Paused },
                onRestart = {
                    app.audio.playTap()
                    // Skor varken yanlış dokunuş turu silmesin — önce sor
                    if (endlessScore > 0) confirmRestart = true else restart()
                }
            )

            if (confirmRestart) {
                ConfirmRestartDialog(
                    theme = theme,
                    onConfirm = { confirmRestart = false; restart() },
                    onDismiss = { confirmRestart = false }
                )
            }

            orbReveal?.let { style ->
                OrbRevealOverlay(style, theme, onEquip = {
                    app.audio.playTap()
                    app.settings.orbStyleId = style.id
                    app.settings.persist()
                    app.progress.markOrbRevealed(style)
                    orbReveal = app.progress.pendingOrbReveal()
                }, onClose = {
                    app.audio.playTap()
                    app.progress.markOrbRevealed(style)
                    orbReveal = app.progress.pendingOrbReveal()
                })
            }

            // Etkileşimli öğretici: engelleyen kart ya da yönlendirme şeridi
            if (overlay == Overlay.None) {
                coach?.let { step ->
                    if (step.isBlocking) {
                        CoachIntroOverlay(step, theme) {
                            app.audio.playTap()
                            when (step) {
                                Coach.HAZARD_INTRO -> { engine.coachFrozen = false; coach = Coach.HAZARD_TIMING }
                                Coach.MOVING_INTRO -> { engine.coachFrozen = false; coach = Coach.MOVING_TIMING }
                                Coach.TIMED_INTRO -> {
                                    engine.coachFrozen = false; coach = null
                                    app.tutorial.markShown(TutorialStore.Step.TIMED)
                                }
                                Coach.BOUNDS_INTRO -> {
                                    app.tutorial.markShown(TutorialStore.Step.BOUNDS)
                                    val id = (playMode as? PlayMode.LevelPlay)?.id
                                    if (id != null && LevelLibrary.hasTimer(id) &&
                                        app.tutorial.shouldShow(TutorialStore.Step.TIMED)) {
                                        coach = Coach.TIMED_INTRO   // dondurma sürsün
                                    } else {
                                        engine.coachFrozen = false; coach = null
                                    }
                                }
                                else -> Unit
                            }
                        }
                    } else {
                        CoachBanner(step, theme)
                    }
                }

                // Antrenman: altta adım adım yönlendiren, engellemeyen yazı
                if (isTutorialLevel && coach == null) {
                    TutorialCaption(tutorialHops)
                }

                // Bölüm başı kartı: numara + zorluk rozeti (~1,6 sn)
                if (levelIntroVisible && currentLevelId != null) {
                    LevelIntroCard(currentLevelId, theme)
                }
            }

            when (val o = overlay) {
                Overlay.None -> Unit
                Overlay.Paused -> PauseOverlay(theme,
                    onResume = { overlay = Overlay.None },
                    onRestart = { restart() },
                    onMenu = onExit
                )
                is Overlay.Won -> WinOverlay(
                    stars = o.stars, maxStars = maxStarsForLevel, celebrationRes = o.celebrationRes,
                    isTutorial = isTutorialLevel, isBonus = isBonusLevel,
                    lumenCount = lumenCount, lumenTotal = engine.lumenTotal, theme = theme,
                    onNext = {
                        if (isTutorialLevel) {
                            onReplay(PlayMode.LevelPlay(1))   // antrenman → 1. bölüm, reklamsız
                        } else {
                            val next = ((currentLevelId ?: 0) + 1).coerceAtMost(LevelLibrary.COUNT)
                            app.ads.levelCompleted(activity, currentLevelId ?: 1, app.billing.isPremium) {
                                onReplay(PlayMode.LevelPlay(next))
                            }
                        }
                    },
                    onMenu = {
                        app.ads.levelCompleted(activity, currentLevelId ?: 1, app.billing.isPremium) { onExit() }
                    }
                )
                is Overlay.EndlessOver -> EndlessOverlay(
                    score = o.score,
                    best = app.progress.endlessBest,
                    theme = theme,
                    canRevive = !revivedThisRun && !app.billing.isPremium,
                    onRevive = {
                        app.audio.playTap()
                        app.ads.showRewarded(activity) { earned ->
                            if (earned) {
                                revivedThisRun = true
                                overlay = Overlay.None
                                engine.reviveEndless()
                                app.haptics.win()
                            }
                        }
                    },
                    onRetry = {
                        app.ads.endlessEnded(activity, app.billing.isPremium, app.progress.endlessUnlocked) {
                            restart()
                        }
                    },
                    onMenu = onExit
                )
                is Overlay.SpeedrunDone -> SpeedrunOverlay(o.time, o.isRecord, theme,
                    onRetry = { restart() }, onMenu = onExit)
            }
        }
    }
}

@Composable
private fun GameHud(
    playMode: PlayMode,
    levelId: Int?,
    lumenCount: Int,
    endlessScore: Int,
    bonusRemaining: Int,
    timeRemaining: Int,
    extraLives: Int,
    theme: Theme,
    onPause: () -> Unit,
    onRestart: () -> Unit
) {
    Column(Modifier.fillMaxSize().padding(16.dp)) {
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                BackButton(onClick = onPause)
                // Sonsuz modda turu bırakıp anında yenisine başlamak için
                if (playMode == PlayMode.Endless) {
                    Box(
                        Modifier
                            .padding(start = 8.dp)
                            .size(44.dp)
                            .background(Color.White.copy(alpha = 0.10f), CircleShape)
                            .clickable(onClick = onRestart),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Filled.Refresh, null, tint = Color.White)
                    }
                }
            }

            Text(
                when (playMode) {
                    PlayMode.Endless -> stringResource(R.string.hud_score, endlessScore)
                    PlayMode.Speedrun -> stringResource(R.string.speed_run)
                    is PlayMode.LevelPlay ->
                        if (levelId == LevelLibrary.TUTORIAL_ID) stringResource(R.string.tutorial)
                        else stringResource(R.string.hud_level, levelId ?: 1)
                },
                color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold
            )

            Row(verticalAlignment = Alignment.CenterVertically) {
                if (timeRemaining >= 0) {
                    Text("$timeRemaining",
                        color = if (timeRemaining <= 3) theme.hazard else Color.White,
                        fontSize = 18.sp, fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(end = 10.dp))
                }
                if (bonusRemaining > 0) {
                    Text("$bonusRemaining", color = theme.lumen,
                        fontSize = 18.sp, fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(end = 10.dp))
                }
                // Premium oyuncu reklam izlemiyor; onun yerine tur başına tek
                // kullanımlık bir canı var, kalpten kaç tane kaldığı burada.
                if (playMode == PlayMode.Endless && extraLives > 0) {
                    Text("♥ $extraLives", color = theme.hazard,
                        fontSize = 16.sp, fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(end = 10.dp))
                }
                if (playMode != PlayMode.Endless) {
                    Text("★ $lumenCount", color = theme.lumen,
                        fontSize = 16.sp, fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}

// MARK: Öğretici koçu

private data class CoachCard(val icon: String, val titleRes: Int, val bodyRes: Int)

@Composable
private fun CoachIntroOverlay(step: Coach, theme: Theme, onDismiss: () -> Unit) {
    val card = when (step) {
        Coach.HAZARD_INTRO -> CoachCard("⚠️", R.string.hint_hazard_title, R.string.hint_hazard_body)
        Coach.MOVING_INTRO -> CoachCard("↔️", R.string.hint_moving_title, R.string.hint_moving_body)
        Coach.TIMED_INTRO -> CoachCard("⏱", R.string.hint_timed_title, R.string.hint_timed_body)
        else -> CoachCard("🛑", R.string.hint_bounds_title, R.string.hint_bounds_body)
    }
    Box(
        Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.72f))
            .clickable(onClick = onDismiss),
        contentAlignment = Alignment.Center
    ) {
        Column(
            Modifier.padding(horizontal = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(card.icon, fontSize = 48.sp)
            Text(stringResource(card.titleRes), color = Color.White,
                fontSize = 27.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
            Text(stringResource(card.bodyRes), color = Color.White.copy(alpha = 0.82f),
                fontSize = 15.sp, textAlign = TextAlign.Center)
            Text("👆 " + stringResource(R.string.tap_to_continue),
                color = Color.White.copy(alpha = 0.55f),
                fontSize = 14.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(top = 10.dp))
        }
    }
}

@Composable
private fun CoachBanner(step: Coach, theme: Theme) {
    val (icon, textRes) = when (step) {
        Coach.HAZARD_TIMING -> "⚠️" to R.string.coach_hazard_wait
        Coach.HAZARD_CLEARED -> "✅" to R.string.coach_hazard_done
        else -> "↔️" to R.string.coach_moving_time
    }
    Box(Modifier.fillMaxSize().padding(bottom = 48.dp), contentAlignment = Alignment.BottomCenter) {
        Row(
            Modifier.padding(horizontal = 28.dp)
                .background(Color.Black.copy(alpha = 0.55f), RoundedCornerShape(20.dp))
                .padding(horizontal = 18.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(icon, fontSize = 22.sp)
            Text(stringResource(textRes), color = Color.White,
                fontSize = 14.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun TutorialCaption(hops: Int) {
    Box(Modifier.fillMaxSize().padding(bottom = 44.dp), contentAlignment = Alignment.BottomCenter) {
        Text(
            stringResource(if (hops == 0) R.string.tut_caption_launch else R.string.tut_caption_collect),
            color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 30.dp)
                .background(Color.Black.copy(alpha = 0.5f), RoundedCornerShape(20.dp))
                .padding(horizontal = 20.dp, vertical = 14.dp)
        )
    }
}

// MARK: Bölüm giriş kartı

/** Bölüm zorluk etiketi — iOS difficultyKey ile aynı eşikler. */
private fun difficultyRes(id: Int): Int? {
    if (id == LevelLibrary.TUTORIAL_ID || LevelLibrary.isBonus(id)) return null
    return when {
        LevelLibrary.normalIndex(id) < 6 -> R.string.difficulty_easy
        LevelLibrary.normalIndex(id) < 20 -> R.string.difficulty_medium
        LevelLibrary.normalIndex(id) < 45 -> R.string.difficulty_hard
        LevelLibrary.normalIndex(id) < 75 -> R.string.difficulty_very_hard
        else -> R.string.difficulty_extreme
    }
}

@Composable
private fun LevelIntroCard(id: Int, theme: Theme) {
    val diffRes = difficultyRes(id)
    val diffColor = when (diffRes) {
        R.string.difficulty_easy -> theme.gate
        R.string.difficulty_medium -> theme.accent
        R.string.difficulty_hard -> theme.lumen
        else -> theme.hazard
    }
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            Modifier.background(Color.Black.copy(alpha = 0.45f), RoundedCornerShape(28.dp))
                .padding(horizontal = 40.dp, vertical = 26.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(
                if (LevelLibrary.isBonus(id)) stringResource(R.string.bonus_title)
                else stringResource(R.string.hud_level, id),
                color = Color.White, fontSize = 36.sp, fontWeight = FontWeight.Black
            )
            if (diffRes != null) {
                Text(stringResource(diffRes), color = Color.Black,
                    fontSize = 13.sp, fontWeight = FontWeight.Bold,
                    modifier = Modifier.background(diffColor, RoundedCornerShape(20.dp))
                        .padding(horizontal = 16.dp, vertical = 6.dp))
            }
        }
    }
}

// MARK: Kaplamalar

@Composable
private fun OverlayScrim(content: @Composable () -> Unit) {
    Box(
        Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.72f)),
        contentAlignment = Alignment.Center
    ) {
        Column(
            Modifier.fillMaxWidth().padding(horizontal = 40.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) { content() }
    }
}

@Composable
private fun PauseOverlay(theme: Theme, onResume: () -> Unit, onRestart: () -> Unit, onMenu: () -> Unit) {
    val app = LocalAppState.current
    OverlayScrim {
        Text(stringResource(R.string.paused), color = Color.White,
            fontSize = 30.sp, fontWeight = FontWeight.Bold)

        // Hızlı ayarlar: ses ve titreşim, oyundan çıkmadan
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            QuickToggle(if (app.settings.soundOn) "🔊" else "🔇") {
                app.settings.soundOn = !app.settings.soundOn
                app.audio.soundEnabled = app.settings.soundOn
                app.settings.persist()
            }
            QuickToggle(if (app.settings.hapticsOn) "📳" else "📴") {
                app.settings.hapticsOn = !app.settings.hapticsOn
                app.haptics.enabled = app.settings.hapticsOn
                app.settings.persist()
            }
        }

        GlowButton(stringResource(R.string.resume), theme.accent, prominent = true, onClick = onResume)
        GlowButton(stringResource(R.string.restart), theme.ring, onClick = onRestart)
        GlowButton(stringResource(R.string.main_menu), Color.White.copy(alpha = 0.7f), onClick = onMenu)
    }
}

/** Sonsuz modda "yeniden başlat" onayı — iyi giden bir tur kazara silinmesin. */
@Composable
private fun ConfirmRestartDialog(theme: Theme, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    OverlayScrim {
        Text(stringResource(R.string.restart_run_title), color = Color.White,
            fontSize = 24.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
        Text(stringResource(R.string.restart_run_body), color = Color.White.copy(alpha = 0.75f),
            fontSize = 15.sp, textAlign = TextAlign.Center)
        GlowButton(stringResource(R.string.restart), theme.hazard, prominent = true, onClick = onConfirm)
        GlowButton(stringResource(R.string.keep_playing), Color.White.copy(alpha = 0.7f), onClick = onDismiss)
    }
}

@Composable
private fun QuickToggle(label: String, onClick: () -> Unit) {
    Box(
        Modifier.background(Color.White.copy(alpha = 0.12f), RoundedCornerShape(27.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 14.dp),
        contentAlignment = Alignment.Center
    ) { Text(label, fontSize = 18.sp) }
}

@Composable
private fun WinOverlay(
    stars: Int, maxStars: Int, celebrationRes: Int?, isTutorial: Boolean, isBonus: Boolean,
    lumenCount: Int, lumenTotal: Int, theme: Theme,
    onNext: () -> Unit, onMenu: () -> Unit
) {
    OverlayScrim {
        if (celebrationRes != null) {
            // 3/3 yıldız: coşkulu, altın parlaklı tebrik başlığı
            Text(stringResource(celebrationRes), color = theme.lumen,
                fontSize = 40.sp, fontWeight = FontWeight.Black)
            Text(
                stringResource(if (isBonus) R.string.bonus_complete else R.string.level_complete_ex),
                color = Color.White.copy(alpha = 0.75f), fontSize = 14.sp, fontWeight = FontWeight.Bold
            )
        } else {
            Text(
                stringResource(
                    when {
                        isTutorial -> R.string.youre_ready
                        isBonus -> R.string.bonus_complete
                        else -> R.string.level_complete_ex
                    }
                ),
                color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.Bold
            )
        }

        if (isBonus) {
            Text("✨ $lumenCount/$lumenTotal", color = Color.White.copy(alpha = 0.85f),
                fontSize = 18.sp, fontWeight = FontWeight.Bold)
        }

        if (!isTutorial) {   // antrenmanda yıldız yok
            Text("★".repeat(stars) + "☆".repeat((maxStars - stars).coerceAtLeast(0)),
                color = theme.lumen, fontSize = 34.sp)
        }

        GlowButton(stringResource(R.string.next_level), theme.accent, prominent = true, onClick = onNext)
        GlowButton(stringResource(R.string.main_menu), Color.White.copy(alpha = 0.7f), onClick = onMenu)
    }
}

@Composable
private fun EndlessOverlay(
    score: Int, best: Int, theme: Theme, canRevive: Boolean,
    onRevive: () -> Unit, onRetry: () -> Unit, onMenu: () -> Unit
) {
    OverlayScrim {
        Text(stringResource(R.string.game_over), color = Color.White,
            fontSize = 30.sp, fontWeight = FontWeight.Bold)
        Text("$score", color = theme.lumen, fontSize = 46.sp, fontWeight = FontWeight.Bold)
        Text(stringResource(R.string.best_score, best),
            color = Color.White.copy(alpha = 0.6f), fontSize = 15.sp)
        // Koşu başına bir kez: reklam izleyip skoru koruyarak devam et
        if (canRevive) {
            GlowButton(stringResource(R.string.continue_watch_ad), theme.lumen,
                prominent = true, onClick = onRevive)
        }
        GlowButton(stringResource(R.string.try_again), theme.accent,
            prominent = !canRevive, onClick = onRetry)
        GlowButton(stringResource(R.string.main_menu), Color.White.copy(alpha = 0.7f), onClick = onMenu)
    }
}

@Composable
private fun SpeedrunOverlay(
    time: Double, isRecord: Boolean, theme: Theme,
    onRetry: () -> Unit, onMenu: () -> Unit
) {
    OverlayScrim {
        Text(stringResource(R.string.speed_run), color = Color.White,
            fontSize = 30.sp, fontWeight = FontWeight.Bold)
        Text(String.format("%.2f s", time), color = theme.lumen,
            fontSize = 40.sp, fontWeight = FontWeight.Bold)
        if (isRecord) {
            Text(stringResource(R.string.new_record), color = theme.gate,
                fontSize = 17.sp, fontWeight = FontWeight.Bold)
        }
        GlowButton(stringResource(R.string.try_again), theme.accent, prominent = true, onClick = onRetry)
        GlowButton(stringResource(R.string.main_menu), Color.White.copy(alpha = 0.7f), onClick = onMenu)
    }
}
