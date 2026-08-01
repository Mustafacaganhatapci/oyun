package com.caganhatapci.orbeon.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.caganhatapci.orbeon.LocalActivity
import com.caganhatapci.orbeon.LocalAppState
import com.caganhatapci.orbeon.R
import com.caganhatapci.orbeon.model.LevelLibrary
import com.caganhatapci.orbeon.services.AdsManager
import com.caganhatapci.orbeon.store.TutorialStore
import com.caganhatapci.orbeon.theme.Theme
import kotlinx.coroutines.delay

sealed class Route {
    data object Menu : Route()
    data object Levels : Route()
    data class Game(val mode: PlayMode) : Route()
    data object Shop : Route()
    data object Settings : Route()
    data object Username : Route()
    data object Ranking : Route()
}

@Composable
fun RootScreen() {
    val app = LocalAppState.current
    val activity = LocalActivity.current
    val theme = Theme.byId(app.settings.themeId)

    var route by remember { mutableStateOf<Route>(Route.Menu) }
    var splashDone by remember { mutableStateOf(false) }

    Box(Modifier.fillMaxSize().background(Color.Black)) {
        when (val r = route) {
            Route.Menu -> MainMenuScreen(
                onPlay = { route = Route.Game(PlayMode.LevelPlay(app.progress.highestUnlocked)) },
                onLevels = { route = Route.Levels },
                onEndless = { route = Route.Game(PlayMode.Endless) },
                onSpeedrun = { route = Route.Game(PlayMode.Speedrun) },
                onShop = { route = Route.Shop },
                onSettings = { route = Route.Settings },
                onRanking = { route = if (app.player.hasUsername) Route.Ranking else Route.Username }
            )
            Route.Levels -> LevelSelectScreen(
                onBack = { route = Route.Menu },
                onPick = { route = Route.Game(PlayMode.LevelPlay(it)) }
            )
            is Route.Game -> GameScreen(
                playMode = r.mode,
                onExit = { route = Route.Menu },
                onReplay = { route = Route.Game(it) }
            )
            Route.Shop -> ShopScreen(onBack = { route = Route.Menu })
            Route.Settings -> SettingsScreen(
                onBack = { route = Route.Menu },
                onShop = { route = Route.Shop },
                onTutorial = { route = Route.Game(PlayMode.LevelPlay(LevelLibrary.TUTORIAL_ID)) }
            )
            Route.Username -> UsernameScreen(onDone = { route = Route.Ranking }, onBack = { route = Route.Menu })
            Route.Ranking -> RankingScreen(onBack = { route = Route.Menu }, onEditName = { route = Route.Username })
        }

        // Reklamdan sonra ara sıra nazik hatırlatma (sırayla Premium / Destek)
        app.ads.nudge?.let { kind ->
            NudgeOverlay(
                kind = kind,
                theme = theme,
                onSeeAll = { app.ads.dismissNudge(); route = Route.Shop },
                onClose = { app.ads.dismissNudge() }
            )
        }

        // Açılış imzası — yalnızca uygulama başlarken bir kez
        AnimatedVisibility(!splashDone, exit = fadeOut()) {
            SplashScreen(theme)
        }
    }

    LaunchedEffect(Unit) {
        delay(1600)
        splashDone = true
        // İlk açılış: doğrudan "nasıl oynanır" antrenman bölümüne
        if (app.tutorial.shouldShow(TutorialStore.Step.LAUNCH)) {
            route = Route.Game(PlayMode.LevelPlay(LevelLibrary.TUTORIAL_ID))
        }
    }
}

@Composable
private fun SplashScreen(theme: Theme) {
    ThemeBackground(theme) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("ORBEON", color = Color.White, fontSize = 42.sp, fontWeight = FontWeight.Black)
                Text(
                    stringResource(R.string.tagline),
                    color = Color.White.copy(alpha = 0.55f),
                    fontSize = 14.sp,
                    modifier = Modifier.padding(top = 8.dp)
                )
            }
        }
    }
}

/**
 * Reklamdan sonra çıkan hatırlatma. Ürün mağazadan geldiyse satın alma
 * buradan doğrudan yapılır — reklamı yeni izlemiş oyuncuyu ayrıca mağazaya
 * yollamak teklifi soğutuyordu.
 */
@Composable
private fun NudgeOverlay(
    kind: AdsManager.Nudge,
    theme: Theme,
    onSeeAll: () -> Unit,
    onClose: () -> Unit
) {
    val app = LocalAppState.current
    val activity = LocalActivity.current
    val isPremiumNudge = kind == AdsManager.Nudge.PREMIUM
    val product = if (isPremiumNudge) app.billing.premiumProduct else app.billing.tipProducts.firstOrNull()

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.72f))
            .clickable(onClick = onClose),
        contentAlignment = Alignment.Center
    ) {
        Column(
            Modifier
                .padding(horizontal = 34.dp)
                .background(Color.Black.copy(alpha = 0.9f), RoundedCornerShape(28.dp))
                .padding(26.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Icon(
                if (isPremiumNudge) Icons.Filled.Star else Icons.Filled.Favorite,
                null, tint = theme.lumen, modifier = Modifier.size(44.dp)
            )
            Text(
                stringResource(if (isPremiumNudge) R.string.nudge_premium_title else R.string.nudge_support_title),
                color = Color.White, fontSize = 21.sp, fontWeight = FontWeight.Bold
            )
            Text(
                stringResource(if (isPremiumNudge) R.string.nudge_premium_body else R.string.nudge_support_body),
                color = Color.White.copy(alpha = 0.8f), fontSize = 14.sp, textAlign = TextAlign.Center
            )

            if (product != null) {
                val price = product.oneTimePurchaseOfferDetails?.formattedPrice ?: ""
                GlowButton(
                    text = stringResource(if (isPremiumNudge) R.string.go_premium else R.string.buy_a_coffee),
                    color = theme.lumen,
                    prominent = true,
                    trailing = price,
                    enabled = !app.billing.purchaseInProgress
                ) {
                    app.billing.purchase(activity, product)
                }
                Text(
                    stringResource(R.string.see_all_options),
                    color = Color.White.copy(alpha = 0.55f), fontSize = 13.sp,
                    modifier = Modifier.clickable(onClick = onSeeAll)
                )
            } else {
                GlowButton(
                    stringResource(if (isPremiumNudge) R.string.see_premium else R.string.support_developer),
                    theme.lumen, prominent = true, onClick = onSeeAll
                )
            }

            Text(
                stringResource(R.string.not_now),
                color = Color.White.copy(alpha = 0.6f), fontSize = 14.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.clickable(onClick = onClose)
            )
        }
    }
}
