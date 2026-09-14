package com.caganhatapci.orbeon.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitFirstDown
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
    SLOW_TIME_INTRO,                                // zamanın yavaşladığı bölüm
    INVERTED_INTRO,                                 // renkler ters
    UPSIDE_DOWN_INTRO,                              // bölüm baş aşağı
    TWO_GATES_INTRO,                                // ikinci, beyaz kapı
    BOUNDS_INTRO;                                   // "kaçırmak artık elenmek"

    val isBlocking get() = this == HAZARD_INTRO || this == MOVING_INTRO ||
                           this == TIMED_INTRO || this == BOUNDS_INTRO ||
                           this == SLOW_TIME_INTRO || this == INVERTED_INTRO ||
                           this == UPSIDE_DOWN_INTRO || this == TWO_GATES_INTRO
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
        ).also { e ->
            // Gizli küre: yavaşlatma ve nişan çizgisi yalnızca bu kürede
            e.setChrono(orbStyle.kind == OrbStyle.Kind.CHRONO)
            // Zamanın büküldüğü an parmakta hafif bir tık — atlayışın kendi
            // titreşiminden daha yumuşak
            e.onChronoToggle = { app.haptics.hop() }
        }
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
            } else if (LevelLibrary.isInverted(id) &&
                       app.tutorial.shouldShow(TutorialStore.Step.INVERTED)) {
                // Bu ÜÇÜ artık kampanyanın başlarında da çıkıyor ve ikisi bir
                // kuralı tersine çeviriyor. Giriş kartındaki tek satır
                // okunmazsa ilk ölüm "oyun bozuk" gibi hissettiriyor; bir kez
                // anlatmak o ölümü öğrenmeye çeviriyor.
                engine.coachFrozen = true
                coach = Coach.INVERTED_INTRO
            } else if (LevelLibrary.isUpsideDown(id) &&
                       app.tutorial.shouldShow(TutorialStore.Step.UPSIDE_DOWN)) {
                engine.coachFrozen = true
                coach = Coach.UPSIDE_DOWN_INTRO
            } else if (LevelLibrary.hasShortcutGate(id) &&
                       app.tutorial.shouldShow(TutorialStore.Step.TWO_GATES)) {
                engine.coachFrozen = true
                coach = Coach.TWO_GATES_INTRO
            } else if (LevelLibrary.slowsTime(id) &&
                       app.tutorial.shouldShow(TutorialStore.Step.SLOW_TIME)) {
                // Yeni bir DÜĞME veriliyor: anlatılmazsa fark edilmez. Bölüm
                // kartındaki tek satır "basılı tut" diyor ama neyin ne kadar
                // sürdüğünü, göstergenin ne olduğunu söylemiyor.
                engine.coachFrozen = true
                coach = Coach.SLOW_TIME_INTRO
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

            // Sessiz: yalnızca sayaç geri alınıyor, ortada toplanan bir şey yok
            is GameEvent.CollectReset -> lumenCount = 0

            // Halka üstündeki kalp toplandı: yıldız sesinden ayrı bir ses,
            // çünkü toplanan şey de ayrı
            is GameEvent.ExtraLifeGained -> {
                extraLives = event.total
                app.audio.playWin()
                app.haptics.win()
            }
            GameEvent.GateUnlocked -> {
                // Bölüm bitirme sesi DEĞİL: kapı açılmak bölümü bitirmiyor,
                // yalnızca yolu açıyor. İkisi aynı sesken oyuncu bitirdiğini
                // sanıp kapıya gitmiyordu.
                app.audio.playGate()
                app.haptics.collect()
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
                    // Chrono "bas–bırak" ile oynanıyor: basılı tutmak zamanı
                    // yavaşlatır, fırlatma parmak KALKINCA olur. Kısa
                    // dokunuşta iki davranış arasında hissedilir fark yok;
                    // fark yalnızca oyuncu beklemeye karar verdiğinde çıkıyor.
                    //
                    // `detectTapGestures` yerine ham olaylar: basma ile
                    // bırakmayı ayrı ayrı duymak gerekiyor.
                    awaitPointerEventScope {
                        while (true) {
                            awaitFirstDown(requireUnconsumed = false)
                            val active = overlay == Overlay.None && coach?.isBlocking != true
                            if (active) engine.onPressStart()
                            var stillDown = true
                            while (stillDown) {
                                val event = awaitPointerEvent()
                                stillDown = event.changes.any { it.pressed }
                            }
                            if (active) engine.onPressEnd()
                        }
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
                OrbRevealOverlay(style, theme, note = null, onEquip = {
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
                                Coach.SLOW_TIME_INTRO -> {
                                    engine.coachFrozen = false; coach = null
                                    app.tutorial.markShown(TutorialStore.Step.SLOW_TIME)
                                }
                                Coach.INVERTED_INTRO -> {
                                    engine.coachFrozen = false; coach = null
                                    app.tutorial.markShown(TutorialStore.Step.INVERTED)
                                }
                                Coach.UPSIDE_DOWN_INTRO -> {
                                    engine.coachFrozen = false; coach = null
                                    app.tutorial.markShown(TutorialStore.Step.UPSIDE_DOWN)
                                }
                                Coach.TWO_GATES_INTRO -> {
                                    engine.coachFrozen = false; coach = null
                                    app.tutorial.markShown(TutorialStore.Step.TWO_GATES)
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
        Coach.SLOW_TIME_INTRO ->
            CoachCard("⏳", R.string.hint_slow_time_title, R.string.hint_slow_time_body)
        Coach.INVERTED_INTRO ->
            CoachCard("◐", R.string.hint_inverted_title, R.string.hint_inverted_body)
        Coach.UPSIDE_DOWN_INTRO ->
            CoachCard("⇅", R.string.hint_upside_down_title, R.string.hint_upside_down_body)
        Coach.TWO_GATES_INTRO ->
            CoachCard("⑂", R.string.hint_two_gates_title, R.string.hint_two_gates_body)
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

/**
 * Bölümün KURALI — uydurma bir zorluk etiketi değil.
 *
 * Burada eskiden "Kolay / Orta / Zor" yazıyordu ve bu bir tahminden ibaretti:
 * eşik yalnızca bölüm numarasına bakıyordu, oysa zorluğu asıl belirleyen o
 * bölümün ne istediği. Üstelik tahmin çoğu zaman yanlış oluyordu. Uyduramadığı
 * şeyi iddia etmek yerine kesin olarak bildiğini söylüyor: bu bölümün kuralı ne.
 *
 * Sıra önemli — bir bölüm hem süreli hem dev yıldızlı olabilir; oyuncuyu en
 * çok bağlayan kural yazılır. 150 sonrası çeşitler ÖNCE geliyor: bunlar
 * kuralın kendisini değiştiriyor, ötekiler yalnızca hedefi.
 */
private fun levelRuleRes(id: Int): Int? {
    if (id == LevelLibrary.TUTORIAL_ID || LevelLibrary.isBonus(id)) return null
    if (LevelLibrary.isInverted(id)) return R.string.rule_white_burns
    if (LevelLibrary.isUpsideDown(id)) return R.string.rule_upside_down
    if (LevelLibrary.hasShortcutGate(id)) return R.string.rule_two_ways_out
    if (LevelLibrary.isCollect(id)) return R.string.rule_collect_every_star
    if (LevelLibrary.hasTimer(id)) return R.string.rule_beat_the_clock
    // Yavaşlatma bir KURAL değil yetenek: oyuncudan bir şey istemiyor. Bu
    // yüzden kısıtlayıcı kuralların ardında — süreli bir bölümde önce süreyi
    // bilmek gerekir, yardımı sonra keşfetmek hoş olur.
    if (LevelLibrary.slowsTime(id)) return R.string.rule_slow_time
    if (LevelLibrary.hasGrandStar(id)) return R.string.rule_giant_star
    // "En az bir yıldız" kuralı artık HER normal bölümde geçerli, o yüzden her
    // kartta yazmıyor: yazsaydı beş bölüm sonra okunmayan bir süs olurdu. İlk
    // bölümlerde bir kez öğretiliyor, sonrasında kilitli duran kapı söylüyor.
    if (id <= 5) return R.string.rule_one_star_opens
    return null
}

@Composable
private fun LevelIntroCard(id: Int, theme: Theme) {
    val ruleRes = levelRuleRes(id)
    val ruleColor = when (ruleRes) {
        R.string.rule_collect_every_star -> theme.gate
        R.string.rule_beat_the_clock -> theme.hazard
        // Ters bölümün rozeti BEYAZ: bölümde öldüren renk hangisiyse o
        R.string.rule_white_burns -> Color.White
        R.string.rule_upside_down -> theme.accent
        R.string.rule_two_ways_out -> Color.White
        // Yavaşlatma rozeti mor: oyunun hiçbir kuralında olmayan bir renk,
        // yani "burada alışılmadık bir şey var" bilgisini renk taşıyor
        R.string.rule_slow_time -> theme.accent
        else -> theme.lumen
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
            if (ruleRes != null) {
                Text(stringResource(ruleRes), color = Color.Black,
                    fontSize = 13.sp, fontWeight = FontWeight.Bold,
                    modifier = Modifier.background(ruleColor, RoundedCornerShape(20.dp))
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
