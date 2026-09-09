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
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import kotlinx.coroutines.launch
import kotlin.math.cos
import kotlin.math.sin
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.width
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import kotlinx.coroutines.delay
import java.util.Calendar
import kotlin.math.roundToInt
import com.caganhatapci.orbeon.services.BillingManager
import com.caganhatapci.orbeon.LocalActivity
import com.caganhatapci.orbeon.LocalAppState
import com.caganhatapci.orbeon.R
import com.caganhatapci.orbeon.model.LevelLibrary
import com.caganhatapci.orbeon.services.AdsManager
import com.caganhatapci.orbeon.services.OfflineNotice
import com.caganhatapci.orbeon.store.TutorialStore
import com.caganhatapci.orbeon.theme.Theme

sealed class Route {
    data object Menu : Route()
    data object Levels : Route()
    data class Game(val mode: PlayMode) : Route()
    /** Karakterler, arka planlar, foto küre — sahip olduklarını düzenlediğin yer */
    data object Personalize : Route()
    /** Yalnızca premium teklifi: faydalar, fiyat, kod, bahşiş */
    data object Premium : Route()
    data object Settings : Route()
    data object Username : Route()
    data object Ranking : Route()
}

@Composable
fun RootScreen() {
    val app = LocalAppState.current
    val activity = LocalActivity.current
    val theme = app.settings.theme

    var route by remember { mutableStateOf<Route>(Route.Menu) }
    var splashDone by remember { mutableStateOf(false) }
    var showOfflineNotice by remember { mutableStateOf(false) }

    Box(Modifier.fillMaxSize().background(Color.Black)) {
        when (val r = route) {
            Route.Menu -> MainMenuScreen(
                onPlay = { route = Route.Game(PlayMode.LevelPlay(app.progress.highestUnlocked)) },
                onLevels = { route = Route.Levels },
                onEndless = { route = Route.Game(PlayMode.Endless) },
                onSpeedrun = { route = Route.Game(PlayMode.Speedrun) },
                onPersonalize = { route = Route.Personalize },
                onPremium = { route = Route.Premium },
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
            Route.Personalize -> PersonalizeScreen(
                onBack = { route = Route.Menu },
                onPremium = { route = Route.Premium }
            )
            Route.Premium -> PremiumScreen(onBack = { route = Route.Menu })
            Route.Settings -> SettingsScreen(
                onBack = { route = Route.Menu },
                onPremium = { route = Route.Premium },
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
                onSeeAll = { app.ads.dismissNudge(); route = Route.Premium },
                onClose = { app.ads.dismissNudge() }
            )
        }

        // Satın alma sonrası adına seslenen teşekkür kartı
        app.billing.thankYou?.let { thanks ->
            ThankYouOverlay(
                kind = thanks.kind,
                username = app.player.username,
                theme = theme
            ) { app.billing.thankYou = null }
        }

        // İnterneti kapalı oynayana bir kez çıkan nazik not (yalnızca menüde)
        if (showOfflineNotice) {
            OfflineNoticeOverlay(
                theme = theme,
                onPremium = {
                    OfflineNotice.markShown(activity)
                    showOfflineNotice = false
                    route = Route.Premium
                },
                onClose = {
                    OfflineNotice.markShown(activity)
                    showOfflineNotice = false
                }
            )
        }

        // Açılış imzası — yalnızca uygulama başlarken bir kez
        AnimatedVisibility(!splashDone, exit = fadeOut()) {
            SplashScreen(theme)
        }
    }

    // Not bir turu asla bölmez: yalnızca menüdeyken ve açılış bittikten sonra
    LaunchedEffect(route, splashDone, app.connectivity.isOnline, app.billing.isPremium) {
        if (splashDone && route == Route.Menu && !showOfflineNotice) {
            showOfflineNotice = OfflineNotice.shouldShow(
                activity, app.connectivity.isOnline,
                app.billing.isPremium, app.progress.totalStars
            )
        }
    }

    // Yıldız her arttığında eşiğe bakılıyor: günlük ödül, görev, ödüllü
    // reklam ve bölüm bitirme — hepsi buradan geçiyor. Açılışta da bakılıyor,
    // çünkü eşik güncellemeden önce geçilmiş olabilir.
    LaunchedEffect(app.progress.totalStars) {
        app.billing.checkStarUnlock(app.progress.totalStars)
    }

    LaunchedEffect(Unit) {
        // Açılış animasyonu ~2,6 sn sürüyor (halka → küre turu → patlama →
        // isim → halkanın O'nun yerine geçmesi → harfler); kurulan kelime
        // işareti bir an dursun diye biraz daha bekleniyor.
        delay(3200)
        splashDone = true
        // İlk açılış: doğrudan "nasıl oynanır" antrenman bölümüne
        if (app.tutorial.shouldShow(TutorialStore.Step.LAUNCH)) {
            route = Route.Game(PlayMode.LevelPlay(LevelLibrary.TUTORIAL_ID))
        }
    }
}

/**
 * Açılış imzası — stüdyo adı üstte, sahne Orbeon marka işaretinin.
 *
 * İşaret oyunun kendisi: nötr bir halka, üstünde tek kırmızı yay, çemberin
 * üstünde dolanan beyaz küre. Animasyon da oyunun kendisi: halka çizilir,
 * küre yörüngeyi tamamlar, kırmızı yay yerine PATLAR — sonra halka küçülerek
 * sola süzülür ve ORBEON'un O'sunun yerine oturur. Yani açılış, markanın
 * nereden geldiğini gösteriyor: işaret ayrı bir amblem değil, kelimenin bir
 * harfi.
 */
@Composable
private fun SplashScreen(theme: Theme) {
    val ringProgress = remember { Animatable(0f) }
    val orbAngle = remember { Animatable(-90f) }
    val hazardIn = remember { Animatable(0f) }     // 0 = dışarıda, 1 = yerinde
    val burst = remember { Animatable(0f) }
    val nameIn = remember { Animatable(0f) }
    val composed = remember { Animatable(0f) }     // halka O'nun yerine geçti
    val lettersIn = remember { Animatable(0f) }    // RBEON açıldı

    LaunchedEffect(Unit) {
        launch { orbAngle.animateTo(270f, tween(1050, easing = FastOutSlowInEasing)) }
        ringProgress.animateTo(1f, tween(1050, easing = FastOutSlowInEasing))

        // Kırmızı yay çöker ve aynı anda patlar
        launch { hazardIn.animateTo(1f, spring(dampingRatio = 0.55f, stiffness = 900f)) }
        launch { burst.animateTo(1f, tween(550, easing = LinearOutSlowInEasing)) }
        delay(220)
        launch { nameIn.animateTo(1f, tween(550, easing = LinearOutSlowInEasing)) }

        // İşaret küçülerek sola süzülür ve O'nun yerine oturur. Küre son
        // çeyreği de dönüp sol alta yerleşiyor: kelimenin içindeki halka
        // duran bir amblem değil, hâlâ oyunun bir karesi.
        delay(500)
        launch { orbAngle.animateTo(315f, spring(dampingRatio = 0.86f, stiffness = 200f)) }
        launch { composed.animateTo(1f, spring(dampingRatio = 0.86f, stiffness = 200f)) }

        // Harfler işaretin ardından açılıyor: önce yer değiştirme okunsun,
        // kelime sonra kurulsun
        delay(300)
        lettersIn.animateTo(1f, tween(450, easing = LinearOutSlowInEasing))
    }

    // Ölçüler. Halka büyükken 118, kelimenin içindeyken 38 punto; oran ikisi
    // arasında TEK bir ölçek ile kuruluyor. Harflerin puntosu ile halkanın
    // çapı ayrı ayrı ayarlanmıyor ki ikisi asla birbirinden kaymasın.
    val markFrame = 190.dp
    val ringBig = 118.dp
    val ringFinal = 38.dp
    val letterSpacing = 13.sp
    // Halka harflerin optik ortasına oturmuyordu: yazı kutusunun ortası alt
    // uzantılar yüzünden harflerin göründüğü ortadan aşağıda kalıyor.
    val ringOpticalLift = 3.dp

    val density = LocalDensity.current
    // Ölçüler PENCERE koordinatında toplanıyor, sonra çıkarılıyor: hangi
    // onGloballyPositioned önce çalışırsa çalışsın sonuç aynı olsun diye
    var rootOrigin by remember { mutableStateOf(Offset.Zero) }
    var rootSize by remember { mutableStateOf(IntSize.Zero) }
    var slotOrigin by remember { mutableStateOf<Offset?>(null) }
    var slotSize by remember { mutableStateOf(IntSize.Zero) }

    ThemeBackground(theme) {
        Box(
            Modifier.fillMaxSize().onGloballyPositioned {
                rootOrigin = it.positionInWindow()
                rootSize = it.size
            }
        ) {
            Column(
                Modifier.fillMaxSize(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Spacer(Modifier.height(78.dp))
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.alpha(nameIn.value)
                ) {
                    Text("AXIUM", color = Color.White.copy(alpha = 0.92f), fontSize = 26.sp,
                         fontWeight = FontWeight.Light, letterSpacing = letterSpacing)
                    Text("DYNAMICS", color = Color.White.copy(alpha = 0.42f), fontSize = 12.sp,
                         letterSpacing = 7.sp, modifier = Modifier.padding(top = 7.dp))
                }

                Spacer(Modifier.weight(1f))

                // Kelime işareti kendi yerinde duruyor; içindeki halka boşluğu
                // ölçülüp üstteki katmana bildiriliyor. Yükseklik marka
                // büyükken de aynı: halka küçülürken sayfa yerinden oynamıyor.
                Box(
                    Modifier.height(markFrame).fillMaxWidth(),
                    contentAlignment = Alignment.Center
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        // Harf aralığı SON harften sonra da boşluk bırakıyor;
                        // kelime işareti sola kaymasın diye yarısı geri alınıyor
                        modifier = Modifier.offset(x = 6.5.dp)
                    ) {
                        // Halkanın yeri BOŞ: gerçek halka üstteki katmanda ve
                        // oraya uçuyor, buradaki şeffaf kutu yalnızca O'nun
                        // nerede duracağını söylüyor
                        Spacer(
                            Modifier.size(ringFinal).onGloballyPositioned {
                                slotOrigin = it.positionInWindow()
                                slotSize = it.size
                            }
                        )
                        Spacer(Modifier.width(9.dp))
                        Text(
                            "RBEON", color = Color.White, fontSize = 42.sp,
                            fontWeight = FontWeight.Light, letterSpacing = letterSpacing,
                            // Harfler halkanın ardından, soldan açılıyor
                            modifier = Modifier.alpha(lettersIn.value)
                                .offset(x = (-14).dp * (1f - lettersIn.value))
                        )
                    }
                    Text(
                        stringResource(R.string.tagline),
                        color = Color.White.copy(alpha = 0.45f), fontSize = 13.sp,
                        letterSpacing = 4.sp,
                        modifier = Modifier.offset(y = 47.dp).alpha(lettersIn.value)
                    )
                }

                Spacer(Modifier.weight(2f))
            }

            // Telif satırı en altta, stüdyo imzasıyla birlikte belirir
            Column(
                Modifier.align(Alignment.BottomCenter).padding(bottom = 26.dp)
                    .alpha(nameIn.value),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text("© ${Calendar.getInstance().get(Calendar.YEAR)} Axium Dynamics",
                     color = Color.White.copy(alpha = 0.28f), fontSize = 11.sp)
                Text(stringResource(R.string.all_rights_reserved),
                     color = Color.White.copy(alpha = 0.28f), fontSize = 11.sp,
                     modifier = Modifier.padding(top = 3.dp))
            }

            // Marka işareti TEK katman: büyük hâliyle ortada duran şeyle O'nun
            // yerine geçen şey aynı görünüm. İki ayrı görünüm arasında geçiş
            // yapılsaydı, birinin sönüp öbürünün belirdiği bir kare olurdu.
            val c = composed.value
            val slotCenter = slotOrigin?.let {
                Offset(
                    it.x - rootOrigin.x + slotSize.width / 2f,
                    it.y - rootOrigin.y + slotSize.height / 2f
                )
            }
            val midY = slotCenter?.y ?: (rootSize.height / 2f)
            val homeX = rootSize.width / 2f
            val targetX = slotCenter?.x ?: homeX
            val liftPx = with(density) { ringOpticalLift.toPx() }
            val framePx = with(density) { markFrame.toPx() }
            val scale = 1f + (ringFinal / ringBig - 1f) * c
            val cx = homeX + (targetX - homeX) * c
            val cy = midY - liftPx * c

            Box(
                Modifier
                    .size(markFrame)
                    .offset {
                        IntOffset((cx - framePx / 2f).roundToInt(),
                                  (cy - framePx / 2f).roundToInt())
                    }
                    .graphicsLayer { scaleX = scale; scaleY = scale }
            ) {
                Canvas(Modifier.fillMaxSize()) {
                    val ctr = Offset(size.width / 2, size.height / 2)
                    val r = 59.dp.toPx()
                    val box = Rect(ctr.x - r, ctr.y - r, ctr.x + r, ctr.y + r)

                    // 1) Halka çizilir
                    drawArc(
                        theme.ring, -90f, 360f * ringProgress.value, false,
                        topLeft = box.topLeft, size = Size(box.width, box.height),
                        style = Stroke(width = 5.dp.toPx(), cap = StrokeCap.Round)
                    )

                    // 2) Kırmızı yay dışarıdan içeri çöker
                    if (hazardIn.value > 0f) {
                        val sc = 1f + (1f - hazardIn.value) * 0.45f
                        val rr = r * sc
                        val hb = Rect(ctr.x - rr, ctr.y - rr, ctr.x + rr, ctr.y + rr)
                        drawArc(
                            theme.hazard.copy(alpha = hazardIn.value.coerceIn(0f, 1f)),
                            -125f, 94f, false,
                            topLeft = hb.topLeft, size = Size(hb.width, hb.height),
                            style = Stroke(width = 11.dp.toPx(), cap = StrokeCap.Round)
                        )
                    }

                    // 3) Patlama: yayın ortasından savrulan parçacıklar
                    if (burst.value > 0f) {
                        val b = burst.value
                        for (i in 0 until 12) {
                            val a = Math.toRadians(-78.0 + (i - 6) * 7.0).toFloat()
                            val dist = r + b * 46.dp.toPx()
                            drawCircle(
                                theme.hazard.copy(alpha = (1f - b).coerceIn(0f, 1f)),
                                2.3.dp.toPx() * (1f - b * 0.55f),
                                Offset(ctr.x + cos(a) * dist, ctr.y + sin(a) * dist)
                            )
                        }
                    }

                    // 4) Küre yörüngede dolanır
                    val oa = Math.toRadians(orbAngle.value.toDouble()).toFloat()
                    drawCircle(theme.orb, 9.5.dp.toPx(),
                               Offset(ctr.x + cos(oa) * r, ctr.y + sin(oa) * r))
                }
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
private fun ThankYouOverlay(
    kind: BillingManager.ThankYou.Kind,
    username: String,
    theme: Theme,
    onClose: () -> Unit
) {
    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.8f))
            .clickable(onClick = onClose),
        contentAlignment = Alignment.Center
    ) {
        Column(
            Modifier
                .padding(horizontal = 30.dp)
                .background(Color.Black.copy(alpha = 0.92f), RoundedCornerShape(28.dp))
                .padding(26.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Text(
                when (kind) {
                    BillingManager.ThankYou.Kind.TIP -> "❤️"
                    BillingManager.ThankYou.Kind.STARS -> "⭐️"
                    else -> "👑"
                },
                fontSize = 44.sp
            )
            // Adı varsa ona seslen; yoksa ad istemeyi seçmiş biri demektir
            Text(
                if (username.isEmpty()) stringResource(R.string.thanks_plain)
                else stringResource(R.string.thanks_named, username),
                color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )
            Text(
                stringResource(
                    when (kind) {
                        BillingManager.ThankYou.Kind.TIP -> R.string.thanks_tip_body
                        BillingManager.ThankYou.Kind.STARS -> R.string.thanks_stars_body
                        else -> R.string.thanks_premium_body
                    }
                ),
                color = Color.White.copy(alpha = 0.8f), fontSize = 14.sp,
                textAlign = TextAlign.Center
            )
            if (kind != BillingManager.ThankYou.Kind.PREMIUM) {
                Text(stringResource(R.string.premium_unlocked), color = theme.gate,
                    fontSize = 14.sp, fontWeight = FontWeight.Bold)
            }
            GlowButton(stringResource(R.string.back_to_game), theme.accent,
                prominent = true, onClick = onClose)
        }
    }
}

@Composable
private fun OfflineNoticeOverlay(theme: Theme, onPremium: () -> Unit, onClose: () -> Unit) {
    val app = LocalAppState.current
    // Fiyat mağazadan gelir (çevrimdışıysa son bilinen fiyattan). Hiç
    // bilinmiyorsa fiyatsız cümleye düşeriz — koda sabit bir rakam yazmayız.
    val price = app.billing.premiumPriceText

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.72f))
            .clickable(onClick = onClose),
        contentAlignment = Alignment.Center
    ) {
        Column(
            Modifier
                .padding(horizontal = 30.dp)
                .background(Color.Black.copy(alpha = 0.9f), RoundedCornerShape(28.dp))
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text("📴", fontSize = 34.sp)
            Text(
                stringResource(R.string.offline_title),
                color = Color.White, fontSize = 21.sp, fontWeight = FontWeight.Bold
            )
            // Tek cümle. Uzun bir açıklama, oyuncuyu savunmaya çeken bir
            // "yakalandın" notu gibi okunuyordu; kısası daha dostça.
            Text(
                if (price != null) stringResource(R.string.offline_premium_priced, price)
                else stringResource(R.string.offline_premium),
                color = Color.White.copy(alpha = 0.8f), fontSize = 14.sp, textAlign = TextAlign.Center
            )
            Text(
                stringResource(R.string.have_fun),
                color = theme.lumen, fontSize = 15.sp, fontWeight = FontWeight.Bold
            )
            GlowButton(stringResource(R.string.keep_playing), theme.accent, prominent = true,
                onClick = onClose)
            Text(
                stringResource(R.string.see_premium),
                color = Color.White.copy(alpha = 0.55f), fontSize = 13.sp,
                modifier = Modifier.clickable(onClick = onPremium)
            )
        }
    }
}

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
