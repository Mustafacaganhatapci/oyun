package com.caganhatapci.orbeon.ui

import android.graphics.Bitmap
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
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
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.foundation.layout.width
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.ui.draw.blur
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.caganhatapci.orbeon.LocalActivity
import com.caganhatapci.orbeon.LocalAppState
import com.caganhatapci.orbeon.R
import com.caganhatapci.orbeon.model.LevelLibrary
import com.caganhatapci.orbeon.model.OrbStyle
import com.caganhatapci.orbeon.services.AdsManager
import com.caganhatapci.orbeon.services.BillingManager
import com.caganhatapci.orbeon.services.CustomSoundSlot
import com.caganhatapci.orbeon.services.LeaderboardService
import com.caganhatapci.orbeon.store.MissionStore
import com.caganhatapci.orbeon.store.OrbPhotoStore
import com.caganhatapci.orbeon.theme.Theme
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

@Composable
private fun ScreenHeader(title: String, onBack: () -> Unit, trailing: @Composable () -> Unit = {}) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        BackButton(onBack)
        Text(title, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        Box(Modifier.size(44.dp), contentAlignment = Alignment.Center) { trailing() }
    }
}

// MARK: Ana menü

@Composable
fun MainMenuScreen(
    onPlay: () -> Unit, onLevels: () -> Unit, onEndless: () -> Unit,
    onSpeedrun: () -> Unit, onShop: () -> Unit, onSettings: () -> Unit, onRanking: () -> Unit
) {
    val app = LocalAppState.current
    val theme = app.settings.theme
    var showMissions by remember { mutableStateOf(false) }
    var claimedFlash by remember { mutableStateOf<Int?>(null) }
    // Günlük ödül ve görev yıldızları da eşik geçirebilir; menüye her
    // dönüşte bekleyen açılış var mı diye bakılıyor
    var orbReveal by remember { mutableStateOf<OrbStyle?>(null) }
    LaunchedEffect(app.progress.totalStars) {
        if (orbReveal == null) orbReveal = app.progress.pendingOrbReveal()
    }

    val frameTime = rememberFrameTime()

    // Kutlama ekranı menünün yerine geçiyor; arkada temanın zemini kalsın
    // diye kendi arka planıyla çiziliyor
    orbReveal?.let { style ->
      ThemeBackground(theme) {
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
      return
    }

    ThemeBackground(theme) {
        AnimatedBlobs(theme, frameTime)
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(28.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Üst şerit: solda premium durumu, sağda sıralama ve ayarlar.
            // Alttaki düğme yığını böylece kısaldı ve menü daha sakin duruyor.
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                PremiumBadge(theme, app.billing.isPremium) { app.audio.playTap(); onShop() }
                Spacer(Modifier.weight(1f))
                Box(
                    Modifier.size(44.dp)
                        .background(Color.White.copy(alpha = 0.1f), CircleShape)
                        .clickable { app.audio.playTap(); onRanking() },
                    contentAlignment = Alignment.Center
                ) { Text("🏆", fontSize = 18.sp) }
                Box(
                    Modifier.size(44.dp)
                        .background(Color.White.copy(alpha = 0.1f), CircleShape)
                        .clickable { app.audio.playTap(); onSettings() },
                    contentAlignment = Alignment.Center
                ) { Text("⚙", color = Color.White.copy(alpha = 0.75f), fontSize = 18.sp) }
            }

            MenuLogo(theme, frameTime)

            // İnce ve geniş aralıklı: kalın siyah harf mat görsel dille çelişiyordu
            Text("ORBEON", color = Color.White, fontSize = 40.sp,
                fontWeight = FontWeight.Light, letterSpacing = 13.sp,
                modifier = Modifier.padding(top = 16.dp))
            Text(stringResource(R.string.tagline), color = Color.White.copy(alpha = 0.55f), fontSize = 13.sp)

            // Ham "x / 806" oyuncuya hiçbir şey söylemiyordu; sıradaki karakter
            // bir hedef veriyor ve toplananın niye toplandığını anlatıyor.
            if (app.progress.totalStars > 0) {
                val goal = app.progress.nextOrbGoal
                if (goal != null) {
                    val (style, remaining) = goal
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(top = 12.dp)
                    ) {
                        Text(
                            "★ " + stringResource(R.string.stars_to_next_character, remaining),
                            color = theme.lumen, fontSize = 15.sp, fontWeight = FontWeight.Bold
                        )
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.padding(top = 6.dp)
                        ) {
                            // Önizleme BULANIK: ne kazanacağını merak etsin
                            CharacterPreview(style.kind, theme, frameTime,
                                Modifier.size(22.dp).blur(5.dp))
                            LinearProgressIndicator(
                                progress = {
                                    app.progress.totalStars.toFloat() /
                                        (style.starCost ?: 1).coerceAtLeast(1)
                                },
                                color = theme.lumen,
                                trackColor = Color.White.copy(alpha = 0.12f),
                                modifier = Modifier.width(120.dp)
                            )
                        }
                    }
                } else {
                    // Hepsi açıldı: toplanan yıldız sayısı burada bir işe
                    // yaramıyor, hedefin bittiğini söylemek yetiyor
                    Text(
                        "★ " + stringResource(R.string.all_characters_unlocked),
                        color = theme.lumen, fontSize = 15.sp, fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(top = 12.dp)
                    )
                }
            }

            // Günlük ödül + görevler
            Row(
                Modifier.fillMaxWidth().padding(top = 26.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    Modifier.weight(1f)
                        .background(
                            if (app.daily.claimedToday) Color.White.copy(alpha = 0.08f) else theme.lumen,
                            RoundedCornerShape(14.dp)
                        )
                        .clickable(enabled = !app.daily.claimedToday) {
                            app.audio.playTap()
                            app.daily.claim()?.let { reward ->
                                app.progress.grantBonusStars(reward)
                                app.audio.playWin(); app.haptics.win()
                                claimedFlash = reward
                            }
                        }
                        .padding(horizontal = 14.dp, vertical = 10.dp)
                ) {
                    Column {
                        Text(
                            if (app.daily.claimedToday) stringResource(R.string.claimed_today)
                            else stringResource(R.string.daily_plus, app.daily.todayReward),
                            color = if (app.daily.claimedToday) Color.White.copy(alpha = 0.5f) else Color.Black,
                            fontSize = 14.sp, fontWeight = FontWeight.Bold
                        )
                        if (app.daily.streak > 0) {
                            Text(
                                stringResource(R.string.day_streak, app.daily.streak),
                                color = if (app.daily.claimedToday) Color.White.copy(alpha = 0.4f)
                                        else Color.Black.copy(alpha = 0.7f),
                                fontSize = 10.sp
                            )
                        }
                    }
                }

                Box(
                    Modifier.size(46.dp)
                        .background(Color.White.copy(alpha = 0.1f), RoundedCornerShape(14.dp))
                        .clickable { app.audio.playTap(); showMissions = !showMissions },
                    contentAlignment = Alignment.Center
                ) {
                    Text("☑", color = Color.White, fontSize = 18.sp)
                    if (app.missions.unclaimedCount > 0) {
                        Box(
                            Modifier.size(10.dp).background(theme.hazard, CircleShape)
                                .align(Alignment.TopEnd)
                        )
                    }
                }
            }

            claimedFlash?.let {
                Text(
                    stringResource(R.string.plus_stars, it),
                    color = theme.lumen, fontSize = 13.sp, fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(top = 6.dp)
                )
            }

            if (showMissions) {
                Card(Modifier.padding(top = 10.dp), corner = 18) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        app.missions.missions.forEach { MissionRow(it, theme) }
                    }
                }
            }

            Column(
                Modifier.fillMaxWidth().padding(top = 24.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                GlowButton(
                    if (app.progress.completedCount == 0) stringResource(R.string.play)
                    else stringResource(R.string.continue_level, app.progress.highestUnlocked),
                    theme.accent, icon = Icons.Filled.PlayArrow, prominent = true
                ) { app.audio.playTap(); onPlay() }

                GlowButton(stringResource(R.string.levels), theme.ring) { app.audio.playTap(); onLevels() }

                GlowButton(
                    stringResource(R.string.endless_mode), theme.gate,
                    enabled = app.progress.endlessUnlocked
                ) { app.audio.playTap(); onEndless() }

                GlowButton(
                    stringResource(R.string.speed_run), theme.hazard,
                    enabled = app.progress.endlessUnlocked
                ) { app.audio.playTap(); onSpeedrun() }

            }
        }
    }
}

/**
 * Sol üst köşe. Premium değilse sade bir çağrı, premiumsa yalnızca bir nişan —
 * ikisi de mağazaya götürüyor, böylece alttaki ikinci düğmeye gerek kalmadı.
 */
@Composable
private fun PremiumBadge(theme: Theme, isPremium: Boolean, onClick: () -> Unit) {
    Row(
        Modifier
            .height(32.dp)
            .background(
                Color.White.copy(alpha = if (isPremium) 0.06f else 0.12f),
                RoundedCornerShape(16.dp)
            )
            .border(
                1.dp,
                if (isPremium) theme.lumen.copy(alpha = 0.55f) else Color.White.copy(alpha = 0.14f),
                RoundedCornerShape(16.dp)
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Text("👑", fontSize = 12.sp)
        if (isPremium) {
            Text("PREMIUM", color = theme.lumen, fontSize = 11.sp, fontWeight = FontWeight.Black)
        } else {
            Text(stringResource(R.string.go_premium), color = Color.White.copy(alpha = 0.85f),
                fontSize = 12.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun MissionRow(mission: MissionStore.Mission, theme: Theme) {
    val app = LocalAppState.current
    Row(verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(stringResource(mission.titleRes), color = Color.White.copy(alpha = 0.9f),
                fontSize = 12.sp, fontWeight = FontWeight.Bold)
            Box(
                Modifier.fillMaxWidth().height(5.dp).padding(top = 4.dp)
                    .background(Color.White.copy(alpha = 0.12f), RoundedCornerShape(3.dp))
            ) {
                Box(
                    Modifier.fillMaxWidth(mission.fraction).height(5.dp)
                        .background(
                            if (mission.isComplete) theme.gate else theme.accent,
                            RoundedCornerShape(3.dp)
                        )
                )
            }
            Text(
                "${mission.progress.coerceAtMost(mission.target)} / ${mission.target}",
                color = Color.White.copy(alpha = 0.5f), fontSize = 10.sp
            )
        }
        when {
            mission.claimed -> Icon(Icons.Filled.CheckCircle, null, tint = theme.gate,
                modifier = Modifier.size(20.dp).padding(start = 8.dp))
            mission.isComplete -> Text(
                "+${mission.reward}",
                color = Color.Black, fontSize = 12.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(start = 8.dp)
                    .background(theme.lumen, RoundedCornerShape(20.dp))
                    .clickable {
                        app.missions.claim(mission.id)?.let {
                            app.progress.grantBonusStars(it)
                            app.audio.playWin(); app.haptics.win()
                        }
                    }
                    .padding(horizontal = 12.dp, vertical = 6.dp)
            )
            else -> Text("+${mission.reward}", color = Color.White.copy(alpha = 0.35f),
                fontSize = 12.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(start = 8.dp))
        }
    }
}

// MARK: Bölüm seçimi

@Composable
fun LevelSelectScreen(onBack: () -> Unit, onPick: (Int) -> Unit) {
    val app = LocalAppState.current
    val theme = app.settings.theme

    ThemeBackground(theme) {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.levels), onBack)
            LazyVerticalGrid(
                columns = GridCells.Fixed(5),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items((1..LevelLibrary.COUNT).toList()) { id ->
                    val unlocked = app.progress.isUnlocked(id)
                    val stars = app.progress.stars[id] ?: 0
                    val isBonus = LevelLibrary.isBonus(id)
                    val isCollect = LevelLibrary.isCollect(id)
                    Box(
                        Modifier
                            .height(58.dp)
                            .background(
                                when {
                                    isBonus -> theme.lumen.copy(alpha = 0.16f)
                                    // Topla-bitir bölümü kapı rengiyle ayrışsın
                                    isCollect -> theme.gate.copy(alpha = 0.16f)
                                    else -> Color.White.copy(alpha = 0.07f)
                                },
                                RoundedCornerShape(14.dp)
                            )
                            .border(
                                1.dp,
                                if (unlocked) theme.ring.copy(alpha = 0.5f) else Color.Transparent,
                                RoundedCornerShape(14.dp)
                            )
                            .clickable(enabled = unlocked) { app.audio.playTap(); onPick(id) },
                        contentAlignment = Alignment.Center
                    ) {
                        if (unlocked) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("$id", color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                                if (stars > 0) {
                                    // "Büyük yıldız" bölümlerinde 4'e kadar
                                    val maxStars = LevelLibrary.maxStars(id)
                                    Text(
                                        "★".repeat(stars) + "☆".repeat((maxStars - stars).coerceAtLeast(0)),
                                        color = theme.lumen, fontSize = 9.sp
                                    )
                                }
                            }
                        } else {
                            Icon(Icons.Filled.Lock, null, tint = Color.White.copy(alpha = 0.3f),
                                modifier = Modifier.size(16.dp))
                        }
                    }
                }
            }
        }
    }
}

// MARK: Mağaza

@Composable
fun ShopScreen(onBack: () -> Unit) {
    val app = LocalAppState.current
    val activity = LocalActivity.current
    val theme = app.settings.theme
    val scroll = rememberScrollState()
    var codeInput by remember { mutableStateOf("") }
    var codeState by remember { mutableStateOf(0) }   // 0 boş, 1 başarılı, 2 hatalı, 3 teselli
    var starsJustEarned by remember { mutableStateOf(false) }
    val frameTime = rememberFrameTime()

    // Premium zaten alınmışsa yukarıda kal; değilse teklifi görsün diye kaydır
    LaunchedEffect(Unit) {
        if (!app.billing.isPremium) {
            kotlinx.coroutines.delay(350)
            scroll.animateScrollTo(520)
        }
    }

    ThemeBackground(theme) {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.shop), onBack) {
                Text("★ ${app.progress.totalStars}", color = theme.lumen,
                    fontSize = 13.sp, fontWeight = FontWeight.Bold)
            }

            Column(
                Modifier.verticalScroll(scroll).padding(horizontal = 20.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                // Ödüllü reklamla bedava yıldız
                if (!app.billing.isPremium) {
                    Card {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(stringResource(R.string.free_stars), color = Color.White,
                                fontSize = 17.sp, fontWeight = FontWeight.Bold)
                            Text(
                                stringResource(R.string.watch_ad_for_stars, BillingManager.REWARDED_STAR_GRANT),
                                color = Color.White.copy(alpha = 0.55f), fontSize = 12.sp
                            )
                            GlowButton(
                                if (starsJustEarned) stringResource(R.string.stars_added)
                                else stringResource(R.string.watch_and_earn),
                                theme.lumen, enabled = !starsJustEarned
                            ) {
                                app.audio.playTap()
                                app.ads.showRewarded(activity) { earned ->
                                    if (earned) {
                                        app.progress.grantBonusStars(BillingManager.REWARDED_STAR_GRANT)
                                        app.audio.playWin(); app.haptics.win()
                                        starsJustEarned = true
                                    }
                                }
                            }
                            app.ads.rewardNotice?.let { notice ->
                                Text(
                                    stringResource(
                                        if (notice == AdsManager.RewardNotice.UNAVAILABLE)
                                            R.string.no_ad_available else R.string.ad_closed_early
                                    ),
                                    color = Color.White.copy(alpha = 0.6f), fontSize = 11.sp,
                                    textAlign = TextAlign.Center,
                                    modifier = Modifier.fillMaxWidth().clickable { app.ads.dismissRewardNotice() }
                                )
                            }
                        }
                    }
                }

                // Yıldızla alınan karakterler
                Card {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(stringResource(R.string.characters), color = Color.White.copy(alpha = 0.9f),
                            fontSize = 16.sp, fontWeight = FontWeight.Bold)
                        Text(stringResource(R.string.unlocks_with_stars),
                            color = Color.White.copy(alpha = 0.45f), fontSize = 12.sp)
                        OrbStyle.starLadder.forEach { style ->
                            CharacterRow(style, theme, frameTime)
                        }
                    }
                }

                // Arka planlar — ayarlardan buraya taşındı: sekizi premium'a
                // dahil olduğu için asıl yeri satın alma ekranı
                Card {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(stringResource(R.string.backgrounds), color = Color.White.copy(alpha = 0.9f),
                            fontSize = 16.sp, fontWeight = FontWeight.Bold)
                        Theme.all.forEach { t ->
                            val locked = t.isPremium && !app.billing.isPremium
                            Row(
                                Modifier.fillMaxWidth()
                                    .background(
                                        if (app.settings.themeId == t.id) t.accent.copy(alpha = 0.2f)
                                        else Color.Transparent,
                                        RoundedCornerShape(12.dp)
                                    )
                                    .clickable {
                                        app.audio.playTap()
                                        // Kilitli tema = premium teklifi; kart aşağıda
                                        if (!locked) {
                                            app.settings.themeId = t.id; app.settings.persist()
                                        }
                                    }
                                    .padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Box(Modifier.size(20.dp).background(t.accent, CircleShape))
                                Text(
                                    stringResource(t.nameRes),
                                    color = Color.White, fontSize = 14.sp,
                                    modifier = Modifier.weight(1f).padding(start = 12.dp)
                                )
                                if (locked) Icon(Icons.Filled.Lock, null,
                                    tint = Color.White.copy(alpha = 0.4f), modifier = Modifier.size(16.dp))
                                else if (app.settings.themeId == t.id)
                                    Icon(Icons.Filled.CheckCircle, null, tint = t.gate, modifier = Modifier.size(18.dp))
                            }
                        }
                    }
                }

                // Premium kartı. Premium alındıysa gösterilmiyor: parası
                // ödenmiş bir şeyin fiyatını her açılışta göstermenin anlamı
                // yok, ekranı da uzatıyordu.
                if (!app.billing.isPremium) Box(
                    Modifier.fillMaxWidth()
                        .background(theme.lumen.copy(alpha = 0.12f), RoundedCornerShape(28.dp))
                        .border(1.5.dp, theme.lumen.copy(alpha = 0.6f), RoundedCornerShape(28.dp))
                        .padding(24.dp)
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text("👑", fontSize = 40.sp)
                        Text(stringResource(R.string.orbeon_premium), color = Color.White,
                            fontSize = 26.sp, fontWeight = FontWeight.Bold)
                        listOf(
                            R.string.benefit_no_ads,
                            R.string.benefit_themes,
                            R.string.benefit_photo,
                            R.string.benefit_support
                        ).forEach {
                            Text("•  ${stringResource(it)}", color = Color.White.copy(alpha = 0.9f),
                                fontSize = 14.sp, modifier = Modifier.fillMaxWidth())
                        }

                        val premium = app.billing.premiumProduct
                        when {
                            premium != null -> GlowButton(
                                stringResource(R.string.go_premium), theme.lumen, prominent = true,
                                trailing = premium.oneTimePurchaseOfferDetails?.formattedPrice ?: "",
                                enabled = !app.billing.purchaseInProgress
                            ) { app.billing.purchase(activity, premium) }
                            app.billing.productsLoaded -> Text(
                                stringResource(R.string.premium_coming_soon),
                                color = Color.White.copy(alpha = 0.6f), fontSize = 13.sp,
                                textAlign = TextAlign.Center
                            )
                            else -> Text("…", color = Color.White.copy(alpha = 0.6f))
                        }
                    }
                }

                // Tanıdık kodu
                if (!app.billing.isPremium) {
                    Card {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(stringResource(R.string.have_a_code), color = Color.White.copy(alpha = 0.85f),
                                fontSize = 14.sp, fontWeight = FontWeight.Bold)
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Box(
                                    Modifier.weight(1f)
                                        .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(12.dp))
                                        .padding(horizontal = 14.dp, vertical = 12.dp)
                                ) {
                                    BasicTextField(
                                        value = codeInput,
                                        onValueChange = { codeInput = it; codeState = 0 },
                                        singleLine = true,
                                        textStyle = TextStyle(color = Color.White, fontSize = 14.sp),
                                        cursorBrush = SolidColor(theme.accent),
                                        modifier = Modifier.fillMaxWidth()
                                    )
                                    if (codeInput.isEmpty()) {
                                        Text(stringResource(R.string.enter_code),
                                            color = Color.White.copy(alpha = 0.35f), fontSize = 14.sp)
                                    }
                                }
                                Text(
                                    stringResource(R.string.redeem),
                                    color = Color.Black, fontSize = 14.sp, fontWeight = FontWeight.Bold,
                                    modifier = Modifier
                                        .background(theme.accent, RoundedCornerShape(20.dp))
                                        .clickable(enabled = codeInput.isNotEmpty()) {
                                            codeState = when {
                                                app.billing.redeem(codeInput) -> {
                                                    app.audio.playWin(); app.haptics.win(); 1
                                                }
                                                app.billing.recordFailedPromoAttempt() -> {
                                                    app.progress.grantBonusStars(BillingManager.PROMO_FAIL_BONUS_STARS)
                                                    app.audio.playWin(); 3
                                                }
                                                else -> { app.audio.playFail(); 2 }
                                            }
                                        }
                                        .padding(horizontal = 16.dp, vertical = 10.dp)
                                )
                            }
                            when (codeState) {
                                1 -> Text(stringResource(R.string.code_accepted), color = theme.gate, fontSize = 12.sp)
                                2 -> Text(stringResource(R.string.invalid_code), color = theme.hazard, fontSize = 12.sp)
                                3 -> Text(stringResource(R.string.code_bonus), color = theme.lumen, fontSize = 12.sp)
                            }
                        }
                    }
                }

                Text(
                    stringResource(R.string.no_pay_to_win),
                    color = Color.White.copy(alpha = 0.55f), fontSize = 12.sp,
                    textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth()
                )

                // Bahşiş kavanozu
                Card {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text(stringResource(R.string.tip_jar), color = Color.White.copy(alpha = 0.9f),
                            fontSize = 16.sp, fontWeight = FontWeight.Bold)
                        Text(stringResource(R.string.tip_jar_body), color = Color.White.copy(alpha = 0.5f),
                            fontSize = 12.sp, textAlign = TextAlign.Center)
                        app.billing.tipProducts.forEach { product ->
                            GlowButton(
                                if (product.productId == BillingManager.TIP_SMALL_ID)
                                    stringResource(R.string.coffee_home) else stringResource(R.string.coffee_cafe),
                                theme.accent,
                                trailing = product.oneTimePurchaseOfferDetails?.formattedPrice ?: "",
                                enabled = !app.billing.purchaseInProgress
                            ) { app.billing.purchase(activity, product) }
                        }
                        if (app.billing.isSupporter) {
                            Text(stringResource(R.string.thanks_support), color = theme.hazard, fontSize = 12.sp)
                        }
                    }
                }

                app.billing.statusMessage?.let { status ->
                    Text(
                        stringResource(
                            when (status) {
                                BillingManager.Status.SUCCESS -> R.string.purchase_complete
                                BillingManager.Status.RESTORED -> R.string.purchases_restored
                                BillingManager.Status.NOTHING_TO_RESTORE -> R.string.nothing_to_restore
                                BillingManager.Status.PENDING -> R.string.purchase_pending
                                BillingManager.Status.FAILED -> R.string.purchase_failed
                            }
                        ),
                        color = when (status) {
                            BillingManager.Status.FAILED -> theme.hazard
                            BillingManager.Status.SUCCESS, BillingManager.Status.RESTORED -> theme.gate
                            else -> Color.White.copy(alpha = 0.7f)
                        },
                        fontSize = 12.sp, textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth().clickable { app.billing.statusMessage = null }
                    )
                }

                Text(
                    stringResource(R.string.restore_purchases),
                    color = Color.White.copy(alpha = 0.6f), fontSize = 13.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(bottom = 40.dp)
                        .clickable { app.billing.restore() }
                )
            }
        }
    }
}

@Composable
private fun CharacterRow(style: OrbStyle, theme: Theme, t: Float) {
    val app = LocalAppState.current
    val owned = app.progress.isOrbUnlocked(style)
    val equipped = app.settings.orbStyleId == style.id
    val cost = style.starCost ?: 0

    // Küreler artık satın alınmıyor: yıldız eşiği geçilince kendiliğinden
    // açılıyor. Kilitliyken önizleme BULANIK ve adı gizli — ne kazanacağını
    // merak etsin, ama ne olduğunu görmesin.
    val remaining = (cost - app.progress.totalStars).coerceAtLeast(0)

    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Box(contentAlignment = Alignment.Center) {
            CharacterPreview(
                style.kind, theme, t,
                Modifier.size(46.dp).then(if (owned) Modifier else Modifier.blur(9.dp))
            )
            if (!owned) {
                Icon(Icons.Filled.Lock, null, tint = Color.White.copy(alpha = 0.75f),
                    modifier = Modifier.size(16.dp))
            }
        }

        Column(Modifier.weight(1f).padding(start = 12.dp)) {
            Text(
                if (owned) stringResource(style.nameRes) else "???",
                color = if (owned) Color.White else Color.White.copy(alpha = 0.55f),
                fontSize = 15.sp, fontWeight = FontWeight.Bold
            )
            if (!owned) {
                Text("★ " + stringResource(R.string.more_stars, remaining),
                    color = theme.lumen, fontSize = 12.sp, fontWeight = FontWeight.Bold)
            }
        }

        when {
            equipped -> Text(stringResource(R.string.equipped), color = theme.gate,
                fontSize = 13.sp, fontWeight = FontWeight.Bold)
            owned -> Text(
                stringResource(R.string.equip), color = Color.Black, fontSize = 13.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.background(theme.accent, RoundedCornerShape(20.dp))
                    .clickable { app.audio.playTap(); app.settings.orbStyleId = style.id; app.settings.persist() }
                    .padding(horizontal = 16.dp, vertical = 8.dp)
            )
            // Eşiğe ne kadar kaldığı çubuktan da okunsun
            else -> LinearProgressIndicator(
                progress = { app.progress.totalStars.toFloat() / cost.coerceAtLeast(1) },
                color = theme.lumen,
                trackColor = Color.White.copy(alpha = 0.12f),
                modifier = Modifier.width(70.dp)
            )
        }
    }
}

// MARK: Ayarlar

@Composable
fun SettingsScreen(onBack: () -> Unit, onShop: () -> Unit, onTutorial: () -> Unit) {
    val app = LocalAppState.current
    val theme = app.settings.theme
    val frameTime = rememberFrameTime()

    ThemeBackground(theme) {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.settings), onBack)
            Column(
                Modifier.verticalScroll(rememberScrollState()).padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Card {
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        ToggleRow(stringResource(R.string.sound), app.settings.soundOn) {
                            app.settings.soundOn = it; app.audio.soundEnabled = it; app.settings.persist()
                        }
                        ToggleRow(stringResource(R.string.music), app.settings.musicOn) {
                            app.settings.musicOn = it; app.audio.musicEnabled = it; app.settings.persist()
                        }
                        ToggleRow(stringResource(R.string.haptics), app.settings.hapticsOn) {
                            app.settings.hapticsOn = it; app.haptics.enabled = it; app.settings.persist()
                        }
                        ToggleRow(stringResource(R.string.colorblind_mode), app.settings.colorBlindOn) {
                            app.settings.colorBlindOn = it; app.settings.persist()
                        }
                        Text(
                            stringResource(R.string.colorblind_mode_note),
                            color = Color.White.copy(alpha = 0.5f), fontSize = 12.sp
                        )
                    }
                }

                // Mağaza ana menüden kaldırıldı (menü kalabalıktı); arka
                // planlar, bahşiş ve premium oraya taşındı
                GlowButton(stringResource(R.string.shop), theme.lumen) {
                    app.audio.playTap(); onShop()
                }

                // Foto küre: premium'sa fotoğraf seç + kuşan (iOS'taki photo orb)
                if (app.billing.isPremium) {
                    PhotoOrbCard(theme, frameTime)
                }

                // Premium: kendi kaydettiğin efekt sesleri
                CustomSoundsCard(theme, onShop)

                GlowButton(stringResource(R.string.how_to_play), theme.ring) { onTutorial() }
            }
        }
    }
}

/**
 * Premium: oyuncu kendi sesini kaydeder, oyun onu sentetik efektin yerine
 * çalar. "Hop" ayrıca komboyla hızlandırılıp inceltilir.
 */
@Composable
private fun CustomSoundsCard(theme: Theme, onShop: () -> Unit) {
    val app = LocalAppState.current
    val sounds = app.customSounds
    var pendingSlot by remember { mutableStateOf<CustomSoundSlot?>(null) }
    var micDenied by remember { mutableStateOf(false) }

    val permission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        micDenied = !granted
        val slot = pendingSlot
        pendingSlot = null
        if (granted && slot != null) sounds.startRecording(slot)
    }

    Card {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.custom_sounds_title), color = Color.White,
                    fontSize = 17.sp, fontWeight = FontWeight.Bold)
                if (!app.billing.isPremium) {
                    Spacer(Modifier.width(8.dp))
                    Text(stringResource(R.string.premium_badge), color = theme.lumen,
                        fontSize = 10.sp, fontWeight = FontWeight.Black,
                        modifier = Modifier
                            .background(theme.lumen.copy(alpha = 0.18f), RoundedCornerShape(8.dp))
                            .padding(horizontal = 7.dp, vertical = 3.dp))
                }
            }
            Text(stringResource(R.string.custom_sounds_body),
                color = Color.White.copy(alpha = 0.5f), fontSize = 12.sp)

            if (!app.billing.isPremium) {
                GlowButton(stringResource(R.string.go_premium), theme.lumen) {
                    app.audio.playTap(); onShop()
                }
            } else {
                ToggleRow(stringResource(R.string.custom_sounds_use), sounds.enabled) {
                    sounds.updateEnabled(it)
                }
                CustomSoundSlot.entries.forEach { slot ->
                    CustomSoundRow(
                        slot = slot,
                        theme = theme,
                        recording = sounds.recording == slot,
                        has = sounds.recorded.contains(slot),
                        onRecord = {
                            if (sounds.recording == slot) {
                                sounds.stopRecording()
                            } else if (sounds.hasMicPermission()) {
                                app.audio.playTap(); sounds.startRecording(slot)
                            } else {
                                pendingSlot = slot
                                permission.launch(android.Manifest.permission.RECORD_AUDIO)
                            }
                        },
                        onPreview = { sounds.preview(slot, app.audio) },
                        onDelete = { app.audio.playTap(); sounds.delete(slot) }
                    )
                }
                if (micDenied) {
                    Text(stringResource(R.string.custom_sounds_mic_denied),
                        color = theme.hazard, fontSize = 12.sp)
                }
            }
        }
    }
}

@Composable
private fun CustomSoundRow(
    slot: CustomSoundSlot,
    theme: Theme,
    recording: Boolean,
    has: Boolean,
    onRecord: () -> Unit,
    onPreview: () -> Unit,
    onDelete: () -> Unit
) {
    val title = when (slot) {
        CustomSoundSlot.HOP -> R.string.sfx_hop
        CustomSoundSlot.LIFE_LOST -> R.string.sfx_life_lost
        CustomSoundSlot.FAIL -> R.string.sfx_death
        CustomSoundSlot.WIN -> R.string.sfx_level_complete
    }
    val hint = when (slot) {
        CustomSoundSlot.HOP -> R.string.sfx_hop_hint
        CustomSoundSlot.LIFE_LOST -> R.string.sfx_life_lost_hint
        CustomSoundSlot.FAIL -> R.string.sfx_death_hint
        CustomSoundSlot.WIN -> R.string.sfx_level_complete_hint
    }
    Row(
        Modifier.fillMaxWidth().padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(stringResource(title), color = Color.White, fontSize = 15.sp)
            Text(
                if (recording) stringResource(R.string.recording_now) else stringResource(hint),
                color = if (recording) theme.hazard else Color.White.copy(alpha = 0.45f),
                fontSize = 11.sp
            )
        }
        if (has && !recording) {
            SmallCircleButton("▶") { onPreview() }
            Spacer(Modifier.width(6.dp))
            SmallCircleButton("✕") { onDelete() }
            Spacer(Modifier.width(6.dp))
        }
        SmallCircleButton(
            if (recording) "■" else "●",
            tint = if (recording) theme.hazard else Color.White,
            onClick = onRecord
        )
    }
}

@Composable
private fun SmallCircleButton(label: String, tint: Color = Color.White, onClick: () -> Unit) {
    Box(
        Modifier
            .size(34.dp)
            .background(Color.White.copy(alpha = 0.10f), CircleShape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Text(label, color = tint.copy(alpha = 0.9f), fontSize = 13.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun ToggleRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, color = Color.White, fontSize = 15.sp)
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

// MARK: Kullanıcı adı

@Composable
fun UsernameScreen(onDone: () -> Unit, onBack: () -> Unit) {
    val app = LocalAppState.current
    val theme = app.settings.theme
    var name by remember { mutableStateOf(app.player.username) }

    ThemeBackground(theme) {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.your_name), onBack)
            Column(
                Modifier.padding(28.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp)
            ) {
                Text(stringResource(R.string.username_body), color = Color.White.copy(alpha = 0.7f), fontSize = 14.sp)
                Box(
                    Modifier.fillMaxWidth()
                        .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(14.dp))
                        .padding(16.dp)
                ) {
                    BasicTextField(
                        value = name,
                        onValueChange = { if (it.length <= 16) name = it },
                        singleLine = true,
                        textStyle = TextStyle(color = Color.White, fontSize = 17.sp),
                        cursorBrush = SolidColor(theme.accent),
                        modifier = Modifier.fillMaxWidth()
                    )
                    if (name.isEmpty()) {
                        Text(stringResource(R.string.enter_name),
                            color = Color.White.copy(alpha = 0.35f), fontSize = 17.sp)
                    }
                }
                GlowButton(
                    stringResource(R.string.save), theme.accent, prominent = true,
                    enabled = name.trim().isNotEmpty()
                ) { app.player.save(name); onDone() }
            }
        }
    }
}

// MARK: Dünya sıralaması

@Composable
fun RankingScreen(onBack: () -> Unit, onEditName: () -> Unit) {
    val app = LocalAppState.current
    val theme = app.settings.theme
    var mode by remember { mutableStateOf(LeaderboardService.Mode.ENDLESS) }

    LaunchedEffect(mode) { app.leaderboard.load(mode) }

    ThemeBackground(theme) {
        Column(Modifier.fillMaxSize()) {
            ScreenHeader(stringResource(R.string.world_ranking), onBack) {
                Text("✎", color = Color.White, fontSize = 18.sp,
                    modifier = Modifier.clickable(onClick = onEditName))
            }

            Row(
                Modifier.fillMaxWidth().padding(horizontal = 20.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                listOf(
                    LeaderboardService.Mode.ENDLESS to R.string.endless_mode,
                    LeaderboardService.Mode.SPEEDRUN to R.string.speed_run
                ).forEach { (m, label) ->
                    Box(Modifier.weight(1f)) {
                        GlowButton(stringResource(label), theme.accent, prominent = mode == m) { mode = m }
                    }
                }
            }

            if (!app.leaderboard.isConfigured) {
                Text(
                    stringResource(R.string.ranking_unavailable),
                    color = Color.White.copy(alpha = 0.6f), fontSize = 13.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(30.dp)
                )
            } else {
                LazyColumn(
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(20.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(app.leaderboard.entries) { entry ->
                        val index = app.leaderboard.entries.indexOf(entry) + 1
                        val isMe = entry.playerId == app.player.playerId
                        Row(
                            Modifier.fillMaxWidth()
                                .background(
                                    if (isMe) theme.accent.copy(alpha = 0.18f) else Color.White.copy(alpha = 0.05f),
                                    RoundedCornerShape(12.dp)
                                )
                                .padding(14.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("$index", color = theme.lumen, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                            Text(entry.username, color = Color.White, fontSize = 14.sp,
                                modifier = Modifier.weight(1f).padding(start = 14.dp))
                            Text(
                                if (mode == LeaderboardService.Mode.ENDLESS) "${entry.value.toInt()}"
                                else String.format("%.2f s", entry.value),
                                color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: Menü görselleri

/** Arka planda süzülen 7 renk lekesi — iOS AnimatedBackground'un karşılığı. */
@Composable
fun AnimatedBlobs(theme: Theme, t: Float) {
    Canvas(Modifier.fillMaxSize()) {
        for (i in 0 until 7) {
            val fi = i.toFloat()
            val x = size.width * (0.5f + 0.42f * sin(t * 0.11f + fi * 2.1f))
            val y = size.height * (0.5f + 0.44f * cos(t * 0.09f + fi * 1.7f))
            val r = 90f + 78f * sin(t * 0.2f + fi)
            val color = if (i % 2 == 0) theme.ring else theme.accent
            drawCircle(
                Brush.radialGradient(
                    listOf(color.copy(alpha = 0.08f), Color.Transparent),
                    center = Offset(x, y), radius = r.coerceAtLeast(1f)
                ),
                r.coerceAtLeast(1f), Offset(x, y)
            )
        }
    }
}

/** Nabız atan logo küresi: parıltı + çekirdek + dış halka. */
@Composable
private fun MenuLogo(theme: Theme, t: Float) {
    // Marka işareti oyunun kendisi: nötr bir halka, üstünde tek kırmızı yay,
    // çemberin üstünde oturan beyaz küre. Yani logo, oyunun bir karesi —
    // parıltısı ve gradyanı olan eski küre, içerinin mat diline uymuyordu.
    // Küre yörüngede ağır ağır dolanıyor: duran bir işaret yerine oyunun tek
    // fiilini gösteriyor.
    Canvas(Modifier.padding(top = 20.dp).size(110.dp)) {
        val c = Offset(size.width / 2, size.height / 2)
        val r = size.minDimension * 0.44f
        val box = Rect(c.x - r, c.y - r, c.x + r, c.y + r)

        drawCircle(theme.ring, r, c, style = Stroke(width = size.minDimension * 0.037f))
        drawArc(
            theme.hazard, -125f, 94f, false,
            topLeft = box.topLeft, size = Size(box.width, box.height),
            style = Stroke(width = size.minDimension * 0.083f, cap = StrokeCap.Round)
        )
        val a = ((t / 9f) * 2f * PI.toFloat()) + (PI / 2).toFloat()
        drawCircle(theme.orb, size.minDimension * 0.078f,
                   Offset(c.x + cos(a) * r, c.y + sin(a) * r))
    }
}

/**
 * Saniye cinsinden akan zaman — animasyonları sürer.
 *
 * Ekran başına BİR kez çağrılır ve değeri alt bileşenlere parametre olarak
 * geçilir. Her önizleme kendi döngüsünü kurarsa (mağazada 12 karakter var)
 * her karede onlarca ayrı yeniden besteleme oluşur ve arayüz kilitlenir.
 */
@Composable
fun rememberFrameTime(): Float {
    var t by remember { mutableStateOf(0f) }
    LaunchedEffect(Unit) {
        var start = 0L
        while (true) {
            androidx.compose.runtime.withFrameNanos { now ->
                // Başlangıcı İLK KAREDEN al. withFrameNanos'ın zaman tabanı
                // System.nanoTime ile aynı olmak zorunda değil; ikisini
                // karıştırmak ilk karelerde negatif süre üretiyordu.
                if (start == 0L) start = now
                t = (now - start) / 1_000_000_000f
            }
        }
    }
    return t
}

// MARK: Karakter önizlemesi (iOS CharacterPreview'un karşılığı)

/** Mağazadaki küçük küre önizlemesi — her stil kendi minik görseliyle. */
@Composable
fun CharacterPreview(kind: OrbStyle.Kind, theme: Theme, t: Float, modifier: Modifier = Modifier) {
    Canvas(
        modifier.background(
            Brush.verticalGradient(listOf(theme.bgTop, theme.bgBottom)), CircleShape
        )
    ) {
        // Ölçüm sırasında bir kare boyut 0 gelebilir; negatif yarıçapla çizim
        // yapmak yerine o kareyi atlıyoruz
        if (size.minDimension < 4f) return@Canvas
        val c = Offset(size.width / 2, size.height / 2)
        drawCircle(Color.White.copy(alpha = 0.12f), size.minDimension / 2 - 1f, c,
            style = Stroke(width = 1.5f))
        when (kind) {
            OrbStyle.Kind.CLASSIC -> drawCircle(theme.orb, 8f, c)
            OrbStyle.Kind.STAR -> rotate(t * 40f, pivot = c) { drawPath(miniStar(c, 10f), theme.lumen) }
            OrbStyle.Kind.CRYSTAL -> rotate(t * 30f, pivot = c) { drawPath(miniPoly(c, 6, 10f), theme.gate) }
            OrbStyle.Kind.COMET -> {
                drawLine(theme.accent.copy(alpha = 0.7f), Offset(c.x - 12f, c.y), c, strokeWidth = 4f)
                drawCircle(Color.White, 6f, c)
            }
            OrbStyle.Kind.RAINBOW -> drawCircle(Color.hsv((t * 90f).mod(360f), 0.7f, 1f), 8f, c)
            OrbStyle.Kind.RING -> drawCircle(theme.orb, 9f, c, style = Stroke(width = 3f))
            OrbStyle.Kind.DIAMOND -> rotate(t * 35f, pivot = c) { drawPath(miniPoly(c, 4, 10f), theme.accent) }
            OrbStyle.Kind.FLAME -> drawCircle(theme.hazard, 8f * (1f + 0.15f * sin(t * 9f)), c)
            OrbStyle.Kind.PIXEL -> drawRect(theme.gate,
                topLeft = Offset(c.x - 7f, c.y - 7f),
                size = androidx.compose.ui.geometry.Size(14f, 14f))
            OrbStyle.Kind.BUBBLE -> {
                drawCircle(Color.White.copy(alpha = 0.25f), 9f, c)
                drawCircle(Color.White.copy(alpha = 0.85f), 9f, c, style = Stroke(width = 1.5f))
            }
            OrbStyle.Kind.HEART -> drawPath(miniHeart(c, 9f), Color(0xFFFF2D55))
            OrbStyle.Kind.FIREFLY -> {
                drawCircle(Color(0xFF291F14), 6f, c)
                val blink = 0.2f + 0.8f * ((sin(t * 4f) + 1f) / 2f)
                drawCircle(Color(0xFFBFFF66).copy(alpha = blink), 4f, Offset(c.x, c.y + 7f))
            }
            OrbStyle.Kind.CLOUD -> {
                val puff = Color.White.copy(alpha = 0.95f)
                drawCircle(puff, 6f, Offset(c.x - 6f, c.y + 1f))
                drawCircle(puff, 8f, c)
                drawCircle(puff, 6f, Offset(c.x + 6f, c.y + 1f))
            }
            OrbStyle.Kind.PHOTO -> drawCircle(Color.White.copy(alpha = 0.8f), 8f, c,
                style = Stroke(width = 2f))
        }
    }
}

private fun miniStar(c: Offset, radius: Float): Path {
    val path = Path()
    for (i in 0 until 10) {
        val r = if (i % 2 == 0) radius else radius * 0.45f
        val a = i * PI.toFloat() / 5 - PI.toFloat() / 2
        val p = Offset(c.x + cos(a) * r, c.y + sin(a) * r)
        if (i == 0) path.moveTo(p.x, p.y) else path.lineTo(p.x, p.y)
    }
    path.close()
    return path
}

private fun miniPoly(c: Offset, sides: Int, radius: Float): Path {
    val path = Path()
    for (i in 0 until sides) {
        val a = i * 2 * PI.toFloat() / sides - PI.toFloat() / 2
        val p = Offset(c.x + cos(a) * radius, c.y + sin(a) * radius)
        if (i == 0) path.moveTo(p.x, p.y) else path.lineTo(p.x, p.y)
    }
    path.close()
    return path
}

private fun miniHeart(c: Offset, s: Float): Path {
    val path = Path()
    path.moveTo(c.x, c.y + s * 0.8f)
    path.cubicTo(c.x - s * 0.4f, c.y + s * 1.1f, c.x - s, c.y + s * 0.2f, c.x - s * 0.9f, c.y - s * 0.25f)
    path.cubicTo(c.x - s * 0.7f, c.y - s * 0.85f, c.x - s * 0.1f, c.y - s * 0.6f, c.x, c.y - s * 0.2f)
    path.cubicTo(c.x + s * 0.1f, c.y - s * 0.6f, c.x + s * 0.7f, c.y - s * 0.85f, c.x + s * 0.9f, c.y - s * 0.25f)
    path.cubicTo(c.x + s, c.y + s * 0.2f, c.x + s * 0.4f, c.y + s * 1.1f, c.x, c.y + s * 0.8f)
    path.close()
    return path
}

// MARK: Foto küre (premium)

/** Galeriden fotoğraf seçtirip küreye yerleştirir; seçince otomatik kuşanır. */
@Composable
private fun PhotoOrbCard(theme: Theme, t: Float) {
    val app = LocalAppState.current
    val activity = LocalActivity.current
    var photo by remember { mutableStateOf<Bitmap?>(OrbPhotoStore.load(activity)) }

    val picker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri != null && OrbPhotoStore.save(activity, uri)) {
            photo = OrbPhotoStore.load(activity)
            app.settings.orbStyleId = "photo"
            app.settings.persist()
            app.audio.playWin()
        }
    }

    Card {
        Row(verticalAlignment = Alignment.CenterVertically) {
            val bmp = photo
            if (bmp != null) {
                androidx.compose.foundation.Image(
                    bitmap = bmp.asImageBitmap(),
                    contentDescription = null,
                    modifier = Modifier.size(46.dp).background(Color.White.copy(alpha = 0.06f), CircleShape)
                        .padding(2.dp)
                )
            } else {
                CharacterPreview(OrbStyle.Kind.PHOTO, theme, t, Modifier.size(46.dp))
            }
            Text(
                stringResource(R.string.choose_photo),
                color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.weight(1f).padding(start = 12.dp)
            )
            Text(
                stringResource(if (app.settings.orbStyleId == "photo") R.string.equipped else R.string.equip),
                color = if (app.settings.orbStyleId == "photo") theme.gate else Color.Black,
                fontSize = 13.sp, fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .background(
                        if (app.settings.orbStyleId == "photo") Color.Transparent else theme.accent,
                        RoundedCornerShape(20.dp)
                    )
                    .clickable {
                        picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    }
                    .padding(horizontal = 14.dp, vertical = 8.dp)
            )
        }
    }
}

/**
 * Yıldız eşiği geçilince açılan yeni karakterin kutlama ekranı.
 *
 * Küreler artık satın alınmıyor: yıldız biriktirmek tek başına ilerleme ve her
 * eşik bir ödül. Ödülün hissedilmesi için açılışın GÖRÜLMESİ gerekiyor —
 * mağazaya girip fark etmesini beklemek, ödülü ödül olmaktan çıkarıyordu.
 */
@Composable
fun OrbRevealOverlay(
    style: OrbStyle,
    theme: Theme,
    onEquip: () -> Unit,
    onClose: () -> Unit
) {
    val t = rememberFrameTime()
    val appeared = remember { Animatable(0f) }
    LaunchedEffect(style.id) {
        appeared.animateTo(1f, spring(dampingRatio = 0.62f, stiffness = 260f))
    }

    Box(
        Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.78f)),
        contentAlignment = Alignment.Center
    ) {
        Column(
            Modifier.padding(horizontal = 34.dp)
                .background(Color.Black.copy(alpha = 0.55f), RoundedCornerShape(28.dp))
                .border(1.5.dp, theme.lumen.copy(alpha = 0.35f), RoundedCornerShape(28.dp))
                .padding(28.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            Text(
                stringResource(R.string.new_character_unlocked).uppercase(),
                color = theme.lumen, fontSize = 13.sp, fontWeight = FontWeight.Bold
            )

            Box(Modifier.size(180.dp), contentAlignment = Alignment.Center) {
                // Yavaşça dönen kesikli çember — kürenin "sunulduğu" his
                Canvas(Modifier.size(148.dp)) {
                    rotate(t * 20f) {
                        drawCircle(
                            theme.lumen.copy(alpha = 0.5f),
                            size.minDimension / 2f,
                            style = Stroke(
                                width = 1.5.dp.toPx(),
                                pathEffect = PathEffect.dashPathEffect(
                                    floatArrayOf(7.dp.toPx(), 11.dp.toPx())
                                )
                            )
                        )
                    }
                }
                CharacterPreview(
                    style.kind, theme, t,
                    Modifier.size((108 * appeared.value).dp.coerceAtLeast(1.dp))
                )
            }

            Text(stringResource(style.nameRes), color = Color.White,
                fontSize = 26.sp, fontWeight = FontWeight.Bold)

            style.starCost?.let {
                Text("★ $it", color = Color.White.copy(alpha = 0.5f), fontSize = 13.sp)
            }

            GlowButton(stringResource(R.string.equip), theme.lumen, prominent = true, onClick = onEquip)
            Text(
                stringResource(R.string.later),
                color = Color.White.copy(alpha = 0.55f), fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.clickable(onClick = onClose).padding(8.dp)
            )
        }
    }
}
