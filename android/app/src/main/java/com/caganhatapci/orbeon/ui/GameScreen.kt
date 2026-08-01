package com.caganhatapci.orbeon.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.caganhatapci.orbeon.LocalActivity
import com.caganhatapci.orbeon.LocalAppState
import com.caganhatapci.orbeon.R
import com.caganhatapci.orbeon.game.GameEngine
import com.caganhatapci.orbeon.game.GameEvent
import com.caganhatapci.orbeon.game.GameMode
import com.caganhatapci.orbeon.model.LevelLibrary
import com.caganhatapci.orbeon.services.LeaderboardService
import com.caganhatapci.orbeon.services.ReviewPrompt
import com.caganhatapci.orbeon.store.MissionStore
import com.caganhatapci.orbeon.theme.Theme
import androidx.compose.material3.Text
import androidx.compose.ui.res.stringResource
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

sealed class PlayMode {
    data class LevelPlay(val id: Int) : PlayMode()
    data object Endless : PlayMode()
    data object Speedrun : PlayMode()
}

private sealed class Overlay {
    data object None : Overlay()
    data object Paused : Overlay()
    data class Won(val stars: Int) : Overlay()
    data class EndlessOver(val score: Int) : Overlay()
    data class SpeedrunDone(val time: Double, val isRecord: Boolean) : Overlay()
}

@Composable
fun GameScreen(playMode: PlayMode, onExit: () -> Unit, onReplay: (PlayMode) -> Unit) {
    val app = LocalAppState.current
    val activity = LocalActivity.current
    val theme = Theme.byId(app.settings.themeId)

    var speedIndex by remember { mutableIntStateOf(0) }
    var speedStart by remember { mutableStateOf(System.currentTimeMillis()) }
    var speedPenalty by remember { mutableStateOf(0.0) }

    val currentLevelId = when (playMode) {
        is PlayMode.LevelPlay -> playMode.id
        PlayMode.Speedrun -> LevelLibrary.speedrunLevels[speedIndex]
        PlayMode.Endless -> null
    }

    var overlay by remember { mutableStateOf<Overlay>(Overlay.None) }
    var lumenCount by remember { mutableIntStateOf(0) }
    var deathsThisLevel by remember { mutableIntStateOf(0) }
    var revivedThisRun by remember { mutableStateOf(false) }
    var endlessScore by remember { mutableIntStateOf(0) }
    var bonusRemaining by remember { mutableIntStateOf(0) }
    var timeRemaining by remember { mutableIntStateOf(-1) }
    var frame by remember { mutableIntStateOf(0) }   // yeniden çizimi tetikler

    // Bölüm değişince motor sıfırdan kurulur
    val engine = remember(currentLevelId, playMode) {
        val mode = if (playMode == PlayMode.Endless) GameMode.Endless
                   else GameMode.LevelMode(currentLevelId ?: 1)
        GameEngine(mode)
    }

    // HUD sayaçları yeni bölümle birlikte sıfırlanır. Bu sıfırlama besteleme
    // sırasında değil yan etki olarak yapılır; Compose'da beste sırasında
    // durum yazmak sonsuz yeniden besteye yol açabiliyor.
    LaunchedEffect(engine) {
        lumenCount = 0
        deathsThisLevel = 0
        bonusRemaining = 0
        timeRemaining = -1
        overlay = Overlay.None
    }

    engine.onEvent = { event ->
        when (event) {
            is GameEvent.Hop -> {
                app.audio.playHop(event.combo)
                app.haptics.hop()
                app.progress.recordHop()
                app.missions.recordHops(1)
            }
            is GameEvent.Collect -> {
                lumenCount = event.total
                app.audio.playCollect()
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
                when (playMode) {
                    is PlayMode.LevelPlay -> {
                        val id = playMode.id
                        if (id == LevelLibrary.TUTORIAL_ID) {
                            app.tutorial.markShown(com.caganhatapci.orbeon.store.TutorialStore.Step.LAUNCH)
                            app.tutorial.markShown(com.caganhatapci.orbeon.store.TutorialStore.Step.GATE)
                        } else {
                            app.progress.complete(id, event.stars)
                            app.missions.recordLevelCleared(deathsThisLevel == 0, event.stars)
                            app.missions.recordLumens(lumenCount)
                            // Oyuncunun en iyi hissettiği an: kusursuz bir bölüm
                            if (event.stars >= 3) {
                                ReviewPrompt.requestAfterGreatRun(activity, app.progress.completedCount)
                            }
                        }
                        overlay = Overlay.Won(event.stars)
                    }
                    PlayMode.Speedrun -> {
                        if (speedIndex < LevelLibrary.speedrunLevels.size - 1) {
                            speedIndex++
                            lumenCount = 0
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
            is GameEvent.Attached -> Unit
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

    ThemeBackground(theme) {
        Box(
            Modifier
                .fillMaxSize()
                .pointerInput(engine) {
                    detectTapGestures { if (overlay == Overlay.None) engine.onTap() }
                }
        ) {
            GameCanvas(engine, theme, frame)
            GameHud(
                playMode = playMode,
                levelId = currentLevelId,
                lumenCount = lumenCount,
                endlessScore = endlessScore,
                bonusRemaining = bonusRemaining,
                timeRemaining = timeRemaining,
                theme = theme,
                onPause = { overlay = Overlay.Paused }
            )

            when (val o = overlay) {
                Overlay.None -> Unit
                Overlay.Paused -> PauseOverlay(theme,
                    onResume = { overlay = Overlay.None },
                    onMenu = onExit
                )
                is Overlay.Won -> WinOverlay(o.stars, currentLevelId, theme,
                    onNext = {
                        val next = (currentLevelId ?: 0) + 1
                        app.ads.levelCompleted(activity, currentLevelId ?: 1, app.billing.isPremium) {
                            onReplay(PlayMode.LevelPlay(next.coerceAtMost(LevelLibrary.COUNT)))
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
                            revivedThisRun = false
                            onReplay(PlayMode.Endless)
                        }
                    },
                    onMenu = onExit
                )
                is Overlay.SpeedrunDone -> SpeedrunOverlay(o.time, o.isRecord, theme, onMenu = onExit)
            }
        }
    }
}

/** Oyun alanının çizimi. Motor yalnızca durumu tutar; burası onu resmeder. */
@Composable
private fun GameCanvas(engine: GameEngine, theme: Theme, frame: Int) {
    Canvas(Modifier.fillMaxSize()) {
        @Suppress("UNUSED_EXPRESSION") frame   // her karede yeniden çiz
        engine.resize(size.width, size.height)
        if (engine.ringSpecs.isEmpty()) return@Canvas

        val camShift = if (engine.mode is GameMode.Endless) size.height / 2f - engine.cameraY else 0f

        translate(top = camShift) {
            drawRings(engine, theme)
            drawLumens(engine, theme)
            drawOrb(engine, theme)
            drawBursts(engine, theme)
        }
    }
}

private fun DrawScope.drawRings(engine: GameEngine, theme: Theme) {
    for (i in engine.ringSpecs.indices) {
        val spec = engine.ringSpecs[i]
        val (cx, cy) = engine.ringCenter(i)
        val r = engine.ringRadius(i)
        val color = if (spec.isGate) theme.gate else theme.ring

        // Halkanın kendisi
        drawCircle(
            color = color.copy(alpha = if (spec.isGate) 0.95f else 0.75f),
            radius = r,
            center = Offset(cx, cy),
            style = Stroke(width = if (spec.isGate) 5f else 3.5f)
        )
        // Kapı ayrıca içeriden hafif dolgu alır: hedef olduğu anlaşılsın
        if (spec.isGate) {
            drawCircle(theme.gate.copy(alpha = 0.12f), r, Offset(cx, cy))
        }

        // Kırmızı tehlike yayları — temas her zaman öldürür
        val rot = engine.elapsed.toFloat() * spec.hazardRotationSpeed
        for (arc in spec.hazardArcs) {
            val startDeg = Math.toDegrees((arc.start + rot).toDouble()).toFloat()
            val sweepDeg = Math.toDegrees((arc.end - arc.start).toDouble()).toFloat()
            drawArc(
                color = theme.hazard,
                startAngle = startDeg,
                sweepAngle = sweepDeg,
                useCenter = false,
                topLeft = Offset(cx - r, cy - r),
                size = Size(r * 2, r * 2),
                style = Stroke(width = 7f)
            )
        }

        // "Devam et ya da düş" — aktif halkada azalan süre yayı
        val attached = engine.orbState as? GameEngine.OrbState.Attached
        if (engine.dwellVisible && attached?.ring == i) {
            val frac = engine.dwellFraction
            drawArc(
                color = if (frac < 0.3f) theme.hazard else theme.lumen.copy(alpha = 0.8f),
                startAngle = -90f,
                sweepAngle = 360f * frac,
                useCenter = false,
                topLeft = Offset(cx - r - 9f, cy - r - 9f),
                size = Size((r + 9f) * 2, (r + 9f) * 2),
                style = Stroke(width = 3f)
            )
        }
    }
}

private fun DrawScope.drawLumens(engine: GameEngine, theme: Theme) {
    for (i in engine.lumens.indices) {
        if (engine.lumenCollected[i]) continue
        val (x, y) = engine.lumenPoint(i)
        drawCircle(theme.lumen.copy(alpha = 0.25f), 13f, Offset(x, y))
        drawCircle(theme.lumen, 6f, Offset(x, y))
    }
}

private fun DrawScope.drawOrb(engine: GameEngine, theme: Theme) {
    if (!engine.orbVisible) return
    val c = Offset(engine.orbX, engine.orbY)
    drawCircle(theme.accent.copy(alpha = 0.30f), 22f, c)
    drawCircle(theme.accent.copy(alpha = 0.18f), 34f, c)
    drawCircle(theme.orb, 9f, c)
}

private fun DrawScope.drawBursts(engine: GameEngine, theme: Theme) {
    for (b in engine.bursts) {
        val progress = (b.age / 0.6f).coerceIn(0f, 1f)
        val alpha = 1f - progress
        val spread = 12f + progress * 46f
        for (k in 0 until b.count) {
            val angle = (2 * PI * k / b.count).toFloat()
            drawCircle(
                color = theme.accent.copy(alpha = alpha * 0.8f),
                radius = 2.5f,
                center = Offset(b.x + cos(angle) * spread, b.y + sin(angle) * spread)
            )
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
    theme: Theme,
    onPause: () -> Unit
) {
    Column(Modifier.fillMaxSize().padding(16.dp)) {
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            BackButton(onClick = onPause)

            Text(
                when (playMode) {
                    PlayMode.Endless -> stringResource(R.string.hud_score, endlessScore)
                    PlayMode.Speedrun -> stringResource(R.string.speed_run)
                    is PlayMode.LevelPlay ->
                        if (levelId == LevelLibrary.TUTORIAL_ID) stringResource(R.string.tutorial)
                        else stringResource(R.string.hud_level, levelId ?: 1)
                },
                color = Color.White,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold
            )

            Row(verticalAlignment = Alignment.CenterVertically) {
                if (timeRemaining >= 0) {
                    Text(
                        "$timeRemaining",
                        color = if (timeRemaining <= 3) theme.hazard else Color.White,
                        fontSize = 18.sp, fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(end = 10.dp)
                    )
                }
                if (bonusRemaining > 0) {
                    Text(
                        "$bonusRemaining",
                        color = theme.lumen, fontSize = 18.sp, fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(end = 10.dp)
                    )
                }
                Text("★ $lumenCount", color = theme.lumen, fontSize = 16.sp, fontWeight = FontWeight.Bold)
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
private fun PauseOverlay(theme: Theme, onResume: () -> Unit, onMenu: () -> Unit) {
    OverlayScrim {
        Text(stringResource(R.string.paused), color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.Bold)
        GlowButton(stringResource(R.string.resume), theme.accent, prominent = true, onClick = onResume)
        GlowButton(stringResource(R.string.main_menu), Color.White.copy(alpha = 0.7f), onClick = onMenu)
    }
}

@Composable
private fun WinOverlay(stars: Int, levelId: Int?, theme: Theme, onNext: () -> Unit, onMenu: () -> Unit) {
    OverlayScrim {
        Text(
            if (stars >= 3) stringResource(R.string.perfect) else stringResource(R.string.level_complete),
            color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.Bold
        )
        Text(
            "★".repeat(stars) + "☆".repeat(3 - stars),
            color = theme.lumen, fontSize = 34.sp
        )
        if (levelId != null && levelId < LevelLibrary.COUNT) {
            GlowButton(stringResource(R.string.next_level), theme.accent, prominent = true, onClick = onNext)
        }
        GlowButton(stringResource(R.string.main_menu), Color.White.copy(alpha = 0.7f), onClick = onMenu)
    }
}

@Composable
private fun EndlessOverlay(
    score: Int, best: Int, theme: Theme, canRevive: Boolean,
    onRevive: () -> Unit, onRetry: () -> Unit, onMenu: () -> Unit
) {
    OverlayScrim {
        Text(stringResource(R.string.game_over), color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.Bold)
        Text("$score", color = theme.lumen, fontSize = 46.sp, fontWeight = FontWeight.Bold)
        Text(stringResource(R.string.best_score, best), color = Color.White.copy(alpha = 0.6f), fontSize = 15.sp)
        // Koşu başına bir kez: reklam izleyip skoru koruyarak devam et
        if (canRevive) {
            GlowButton(stringResource(R.string.continue_watch_ad), theme.lumen, prominent = true, onClick = onRevive)
        }
        GlowButton(stringResource(R.string.try_again), theme.accent, prominent = !canRevive, onClick = onRetry)
        GlowButton(stringResource(R.string.main_menu), Color.White.copy(alpha = 0.7f), onClick = onMenu)
    }
}

@Composable
private fun SpeedrunOverlay(time: Double, isRecord: Boolean, theme: Theme, onMenu: () -> Unit) {
    OverlayScrim {
        Text(stringResource(R.string.speed_run), color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.Bold)
        Text(String.format("%.2f s", time), color = theme.lumen, fontSize = 40.sp, fontWeight = FontWeight.Bold)
        if (isRecord) {
            Text(stringResource(R.string.new_record), color = theme.gate, fontSize = 17.sp, fontWeight = FontWeight.Bold)
        }
        GlowButton(stringResource(R.string.main_menu), Color.White.copy(alpha = 0.7f), prominent = true, onClick = onMenu)
    }
}
