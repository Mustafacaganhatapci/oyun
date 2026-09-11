package com.caganhatapci.orbeon.ui

import android.graphics.Bitmap
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform
import com.caganhatapci.orbeon.game.GameEngine
import com.caganhatapci.orbeon.game.GameMode
import com.caganhatapci.orbeon.model.LevelLibrary
import com.caganhatapci.orbeon.model.OrbStyle
import com.caganhatapci.orbeon.theme.Theme
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

/**
 * Oyun alanının çizimi — iOS'taki SpriteKit sahnesinin birebir karşılığı.
 * Motor yalnızca durum tutar; tüm görsel (halka nabzı, kapının kesikli
 * çemberi, küre stilleri, iz, patlamalar) burada, `elapsed` üzerinden
 * deterministik olarak üretilir.
 */
@Composable
fun GameCanvas(engine: GameEngine, theme: Theme, orbStyle: OrbStyle, orbPhoto: Bitmap?, frame: Int) {
    val photoImage: ImageBitmap? = remember(orbPhoto) { orbPhoto?.asImageBitmap() }

    Canvas(Modifier.fillMaxSize()) {
        @Suppress("UNUSED_EXPRESSION") frame   // her karede yeniden çiz
        if (size.minDimension < 4f) return@Canvas
        engine.resize(size.width, size.height, density)
        if (engine.ringSpecs.isEmpty()) return@Canvas

        val t = engine.elapsed.toFloat()
        val den = density

        // Ölümde kısa yatay sarsıntı (iOS'taki shake)
        val shake = if (engine.shakeTime > 0f)
            sin(engine.shakeTime * 90f) * 8f * den * (engine.shakeTime / 0.16f)
        else 0f

        val camShift = if (engine.mode is GameMode.Endless) size.height / 2f - engine.cameraY else 0f

        drawStars(theme, t, camShift, den)

        translate(left = shake, top = camShift) {
            drawTrail(engine, theme, orbStyle, den)
            drawRings(engine, theme, t, den)
            drawLumens(engine, theme, t, den)
            drawLifePickups(engine, theme, t, den)
            drawAimLine(engine, theme, t, den)
            drawOrb(engine, theme, orbStyle, photoImage, t, den)
            drawBursts(engine, theme, den)
        }

        if (engine.tapHintVisible) drawTapHint(theme, t, den)
    }
}

/** Yavaşça yukarı süzülen soluk yıldız alanı (iOS'taki stars emitter'ı). */
private fun DrawScope.drawStars(theme: Theme, t: Float, camShift: Float, den: Float) {
    for (i in 0 until 42) {
        // Deterministik dağılım: her yıldızın kendi konumu, hızı ve parıltısı
        val seed = i * 2654435761L
        val fx = ((seed shr 8) and 0xFFFF).toFloat() / 0xFFFF
        val fy = ((seed shr 24) and 0xFFFF).toFloat() / 0xFFFF
        val speed = (4f + fx * 6f) * den
        val x = fx * size.width
        val y = (fy * size.height - t * speed + camShift * 0.3f).mod(size.height)
        val twinkle = 0.18f + 0.14f * sin(t * 0.8f + i)
        val r = (1.2f + fy * 2.2f) * den
        drawCircle(theme.ring.copy(alpha = twinkle), r, Offset(x, y))
    }
}

private fun DrawScope.drawTrail(engine: GameEngine, theme: Theme, orbStyle: OrbStyle, den: Float) {
    val comet = orbStyle.kind == OrbStyle.Kind.COMET
    val life = if (comet) 0.9f else 0.45f
    for (p in engine.trail) {
        val a = (1f - p.age / life).coerceIn(0f, 1f)
        if (a <= 0f) continue
        val r = (if (comet) 7f else 5f) * a * den
        drawCircle(theme.accent.copy(alpha = a * 0.22f), r * 1.7f, Offset(p.x, p.y))
        drawCircle(theme.accent.copy(alpha = a * 0.8f), r, Offset(p.x, p.y))
    }
}

private fun DrawScope.drawRings(engine: GameEngine, theme: Theme, t: Float, den: Float) {
    val isTutorial = engine.isTutorial
    for (i in engine.ringSpecs.indices) {
        val spec = engine.ringSpecs[i]
        val (cx, cy) = engine.ringCenter(i)
        val c = Offset(cx, cy)
        val baseR = engine.ringRadius(i)

        // Nabız: normal halka hafif (1.03), öğretici kapısı belirgin (1.10)
        val breath = if (spec.isGate && isTutorial)
            1.04f + 0.06f * sin(t * (PI / 0.7).toFloat())
        else
            1.01f + 0.02f * sin(t * (PI / 1.6).toFloat() + i)
        val r = baseR * breath

        // Öğreticide hedef bariz YEŞİL — ama renk körlüğü modunda o yeşil tam
        // da ayırt edilemeyen renk; orada temanın güvenli kapı rengi kalıyor
        // Kaçış kapısı BEYAZ: yeşil kapı "bölümün sonu", beyaz kapı "buradan
        // da çıkabilirsin". İkisi aynı renk olsaydı seçim diye bir şey kalmaz,
        // oyuncu yakın olana gider ve farkı hiç görmezdi.
        val gateColor = when {
            spec.isShortcutGate -> Color.White
            isTutorial && !theme.isColorBlindSafe -> Color(0xFF34C759)
            else -> theme.gate
        }
        // Ters bölümde halkanın KENDİSİ kırmızı. Bölüme girer girmez, tek bir
        // yazı okumadan kuralın değiştiği anlaşılıyor.
        val color = when {
            spec.isGate -> gateColor
            engine.invertedHazard -> theme.hazard
            else -> theme.ring
        }

        // Topla-bitir bölümünde kapı, her şey toplanana kadar sönük durur —
        // "buraya gelmek yetmiyor" bilgisi renkten okunsun
        val locked = spec.isGate && engine.gateLocked
        val dim = if (locked) 0.39f else 1f

        // Dış parıltı + çizginin kendisi
        // Mat dil: parıltı yok, yalnızca kapı çok hafif bir hâle taşıyor
        if (spec.isGate) {
            drawCircle(color.copy(alpha = 0.14f * dim), r, c,
                style = Stroke(width = 12f * den))
        }
        // Halka zeminden net ayrılsın: arka planlar koyulaştı, çizgi de tam
        // opaklığa çıktı. Düşük kontrast, parlaklıktan çok göz yoruyor.
        drawCircle(color.copy(alpha = 1f * dim), r, c, style = Stroke(width = 3.5f * den))

        if (spec.isGate) {
            drawCircle(gateColor.copy(alpha = 0.10f * dim), r, c)
            // Yavaşça dönen kesikli dış çember (kilitliyken 26 sn, açıkken 14)
            rotate(degrees = t * (360f / if (locked) 26f else 14f), pivot = c) {
                drawCircle(
                    gateColor.copy(alpha = 0.7f * dim), r + 12f * den, c,
                    style = Stroke(width = 2f * den,
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(8f * den, 10f * den)))
                )
            }
        }

        // Tehlike yayları: parıltılı, yuvarlak uçlu. Taban her zaman KIRMIZI;
        // müsamaha varsa üstüne, süre doldukça iki ucundan geri çekilen yeşil
        // bir kaplama biniyor. Geri sayımın kendisi yayın üstünde okunuyor:
        // yeşil bittiği an yay silahlanmış oluyor.
        val rot = t * spec.hazardRotationSpeed
        val safeFraction = engine.hazardSafeFraction(i)
        for (arc in spec.hazardArcs) {
            val startDeg = Math.toDegrees((arc.start + rot).toDouble()).toFloat()
            val sweepDeg = Math.toDegrees((arc.end - arc.start).toDouble()).toFloat()
            val box = Rect(cx - r, cy - r, cx + r, cy + r)
            // Kırmızı yalnızca yeşilin BIRAKTIĞI uçlarda duruyor; ikisi üst
            // üste binerse üstteki yeşilin kenarından alttaki kırmızı sızıyor
            // ve yay daha konmadan kırmızı konturluymuş gibi görünüyordu.
            val safeSweep = sweepDeg * safeFraction
            val safeStart = startDeg + (sweepDeg - safeSweep) / 2f
            val redSweep = (sweepDeg - safeSweep) / 2f
            // Ters bölümde öldüren yay BEYAZ; halka zaten kırmızı çizildi
            val deadly = if (engine.invertedHazard) Color.White else theme.hazard
            if (redSweep > 0.05f) {
                for (rs in listOf(startDeg, safeStart + safeSweep)) {
                    drawArc(deadly.copy(alpha = 0.16f), rs, redSweep, false,
                        topLeft = box.topLeft, size = Size(box.width, box.height),
                        style = Stroke(width = 11f * den, cap = StrokeCap.Round))
                    drawArc(deadly, rs, redSweep, false,
                        topLeft = box.topLeft, size = Size(box.width, box.height),
                        style = Stroke(width = 7f * den, cap = StrokeCap.Round))
                }
            }
            if (safeFraction > 0.001f) {
                // Ortadan iki yana açılan yeşil: kırmızı dışarıdan içeri kapanır
                drawArc(theme.hazardSafe, safeStart, safeSweep, false,
                    topLeft = box.topLeft, size = Size(box.width, box.height),
                    style = Stroke(width = 7f * den, cap = StrokeCap.Round))
            }
            // Renk körlüğü modunda tehlike yayı ayrıca ÇENTİKLİ çiziliyor.
            // Renk hangi palete çevrilirse çevrilsin tek başına yetmiyor;
            // yaya dik kısa çentikler yayı halkadan şekliyle ayırıyor.
            if (theme.isColorBlindSafe) {
                val spacing = max(0.14f, 16f * den / max(r, 1f))
                var a = arc.start + rot + spacing / 2f
                while (a < arc.end + rot) {
                    val inner = 8f * den
                    drawLine(
                        theme.bgBottom,
                        Offset(cx + cos(a) * (r - inner), cy + sin(a) * (r - inner)),
                        Offset(cx + cos(a) * (r + inner), cy + sin(a) * (r + inner)),
                        strokeWidth = 2.5f * den, cap = StrokeCap.Round
                    )
                    a += spacing
                }
            }
        }

        // "Devam et ya da düş" — aktif halkada azalan süre yayı.
        // Tehlikeli halkada ÇİZİLMİYOR: o halkanın kendi yayı zaten yeşilden
        // kırmızıya doğru eriyor, ikinci bir sayaç halkası aynı bilgiyi ikinci
        // kez ve karışık anlatıyordu. Süre yine işliyor, göstergesi yok.
        val attached = engine.orbState as? GameEngine.OrbState.Attached
        if (engine.dwellVisible && attached?.ring == i && spec.hazardArcs.isEmpty()) {
            val frac = engine.dwellFraction
            val rr = r + 9f * den
            // Arkasına bir yuva çemberi konmuştu; tehlike yayları artık kendi
            // geri sayımını taşıdığı ve bu yay da bitmeye yakın kırmızıya
            // döndüğü için fazlalıktı — ekranda halka sayısını iki katına
            // çıkarmaktan başka işi yoktu.
            drawArc(
                if (frac < 0.3f) theme.hazard else theme.lumen.copy(alpha = 0.8f),
                -90f, 360f * frac, false,
                topLeft = Offset(cx - rr, cy - rr), size = Size(rr * 2, rr * 2),
                style = Stroke(width = 3f * den, cap = StrokeCap.Round)
            )
        }
    }
}

/**
 * Sonsuz moddaki can kalpleri — halkanın üstünde duruyorlar.
 *
 * Nabız ÇİFT vuruşlu: yıldızların yumuşak salınımından ayrışsın diye. İkisi
 * de altın/kırmızı ve aynı büyüklükte olsaydı uzaktan ayırt edilemezdi.
 */
private fun DrawScope.drawLifePickups(engine: GameEngine, theme: Theme, t: Float, den: Float) {
    if (engine.lifePickups.isEmpty()) return
    for ((_, pos) in engine.lifePickups) {
        val (px, py) = engine.lifePoint(pos)
        val c = Offset(px, py)
        val beat = t * 1.6f
        val phase = beat - kotlin.math.floor(beat)
        val pulse = when {
            phase < 0.12f -> 1f + 0.22f * (phase / 0.12f)
            phase < 0.28f -> 1.22f - 0.22f * ((phase - 0.12f) / 0.16f)
            phase < 0.38f -> 1f + 0.14f * ((phase - 0.28f) / 0.10f)
            phase < 0.56f -> 1.14f - 0.14f * ((phase - 0.38f) / 0.18f)
            else -> 1f
        }
        val r = 9f * den * pulse
        drawCircle(theme.hazard.copy(alpha = 0.20f), r * 2.1f, c)
        drawPath(heartPath(c, r), theme.hazard)
        drawPath(heartPath(c, r), Color.White.copy(alpha = 0.85f),
                 style = Stroke(width = 1f * den))
        // `pos` normalize; sahne koordinatına çevirmek motorun işi, çünkü
        // oynanabilir alanın kenar boşlukları orada tanımlı
    }
}

private fun DrawScope.drawLumens(engine: GameEngine, theme: Theme, t: Float, den: Float) {
    for (i in engine.lumens.indices) {
        if (engine.lumenCollected[i]) continue
        val (x, y) = engine.lumenPoint(i)
        // Nabız: 0.8 sn'de büyü-parla, 0.8 sn'de söner (iOS ile aynı ritim)
        val phase = sin(t * (PI / 0.8).toFloat() + i * 1.3f)
        val s = 1.07f + 0.18f * phase
        val a = 0.87f + 0.13f * phase
        val c = Offset(x, y)
        if (engine.lumenValues.getOrElse(i) { 1 } > 1) {
            // Büyük yıldız 4 eder; bunu tek bakışta anlatması için hem iri
            // hem de daire yerine dönen beş köşeli yıldız olarak çizilir
            val grandPhase = sin(t * (PI / 0.55).toFloat() + i * 1.3f)
            val gs = 1.07f + 0.18f * grandPhase
            val ga = 0.87f + 0.13f * grandPhase
            drawCircle(theme.lumen.copy(alpha = 0.14f * ga), 22f * gs * den, c)
            rotate(degrees = (t * 60f).mod(360f), pivot = c) {
                drawPath(
                    starPath(c, 17f * gs * den, 7.4f * gs * den),
                    theme.lumen.copy(alpha = ga)
                )
            }
        } else {
            drawCircle(theme.lumen.copy(alpha = 0.18f * a), 12f * s * den, c)
            drawCircle(theme.lumen.copy(alpha = a), 7f * s * den, c)
        }
    }
}

/** Antrenman: küre O AN fırlatılırsa gideceği yönü gösteren kesikli çizgi. */
private fun DrawScope.drawAimLine(engine: GameEngine, theme: Theme, t: Float, den: Float) {
    // Antrenman çizgisi sabit boyda; chrono çizgisi çarpacağı halkada
    // KESİLİYOR ve oraya nabız atan bir nokta koyuyor.
    if (!engine.isTutorial && !engine.usesChronoAim) return
    val s = engine.orbState as? GameEngine.OrbState.Attached ?: return
    val start = Offset(engine.orbX, engine.orbY)
    val tx = -sin(s.angle) * s.direction
    val ty = cos(s.angle) * s.direction

    val hit = if (engine.usesChronoAim) engine.chronoAim else null
    val end = if (hit != null) Offset(hit.first, hit.second)
              else Offset(start.x + tx * size.width * 0.5f, start.y + ty * size.width * 0.5f)

    // Hiçbir halkayı kesmiyorsa çizgi soluk: "şu an fırlatma" demenin en
    // sessiz yolu. İnilecek yer kırmızıysa çizgi de kırmızı.
    val color = when {
        engine.usesChronoAim && hit == null -> Color.White.copy(alpha = 0.22f)
        engine.chronoAimDeadly -> theme.hazard.copy(alpha = 0.85f)
        else -> Color.White.copy(alpha = 0.7f)
    }

    drawLine(
        color, start = start, end = end,
        strokeWidth = 3f * den,
        cap = StrokeCap.Round,
        pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f * den, 9f * den))
    )

    if (hit != null) {
        val pulse = 1f + 0.25f * sin(t * (PI / 0.5f).toFloat())
        drawCircle(color, 9f * den * pulse, end, style = Stroke(width = 2f * den))
    }
}

/** Dokunuş ipucu: nabız gibi genişleyen halka + el simgesi (ilk fırlatmaya dek). */
private fun DrawScope.drawTapHint(theme: Theme, t: Float, den: Float) {
    val c = Offset(size.width * 0.80f, size.height * 0.68f)
    val cycle = (t % 1.1f) / 1.1f
    drawCircle(Color.White.copy(alpha = 0.8f * (1f - cycle)), 34f * den * (1f + cycle), c,
        style = Stroke(width = 2f * den))
    val handPulse = 1f - 0.12f * ((sin(t * 7f) + 1f) / 2f)
    scale(handPulse, pivot = c) {
        drawCircle(Color.White, 12f * den, c)
        drawCircle(Color.White, 5f * den, Offset(c.x, c.y - 18f * den))
    }
}

// MARK: Küre — seçilen stile göre çizilir (iOS setupOrb'un karşılığı)

private fun DrawScope.drawOrb(
    engine: GameEngine, theme: Theme, style: OrbStyle, photo: ImageBitmap?, t: Float, den: Float
) {
    if (!engine.orbVisible) return
    val c = Offset(engine.orbX, engine.orbY)
    val r = engine.orbRadiusPx   // 9 punto × yoğunluk

    // Ortak parıltı havuzu
    drawCircle(Brush.radialGradient(
        listOf(theme.orb.copy(alpha = 0.55f), Color.Transparent),
        center = c, radius = r * 3.5f), r * 3.5f, c)

    when (style.kind) {
        OrbStyle.Kind.CLASSIC -> drawCircle(theme.orb, r, c)

        OrbStyle.Kind.STAR -> rotate(t * (360f / 3.5f), pivot = c) {
            drawPath(starPath(c, r * 1.5f), theme.lumen)
        }

        OrbStyle.Kind.CRYSTAL -> rotate(t * (360f / 6f), pivot = c) {
            val p = polygonPath(c, 6, r * 1.35f)
            drawPath(p, theme.gate.copy(alpha = 0.85f))
            drawPath(p, Color.White, style = Stroke(width = 1.5f * den))
        }

        OrbStyle.Kind.COMET -> drawCircle(Color.White, r * 0.85f, c)

        OrbStyle.Kind.RAINBOW -> {
            val hue = (t.mod(4f) / 4f) * 360f
            drawCircle(Color.hsv(hue, 0.7f, 1f), r, c)
        }

        OrbStyle.Kind.RING -> drawCircle(theme.orb, r * 1.15f, c, style = Stroke(width = 3.5f * den))

        OrbStyle.Kind.DIAMOND -> rotate(t * (360f / 4.5f), pivot = c) {
            val p = polygonPath(c, 4, r * 1.4f)
            drawPath(p, theme.accent)
            drawPath(p, Color.White, style = Stroke(width = 1.5f * den))
        }

        OrbStyle.Kind.FLAME -> {
            // Adı "Alev" ama eskiden yalnızca nabız atan kırmızı bir toptu:
            // ne adına ne de mağazadaki önizlemesine benziyordu.
            val w = 1f + 0.09f * sin(t * (PI / 0.32).toFloat())
            drawPath(flamePath(c, r * 1.15f, w, 2f - w), theme.hazard)
            val iw = 1f - 0.09f * sin(t * (PI / 0.26).toFloat())
            drawPath(
                flamePath(Offset(c.x, c.y + r * 0.15f), r * 0.6f, iw, 2f - iw),
                theme.lumen
            )
        }

        OrbStyle.Kind.PIXEL -> {
            val s = r * 1.7f
            drawRect(theme.gate, topLeft = Offset(c.x - s / 2, c.y - s / 2), size = Size(s, s))
            drawRect(Color.White, topLeft = Offset(c.x - s / 2, c.y - s / 2), size = Size(s, s),
                style = Stroke(width = 1f * den))
        }

        OrbStyle.Kind.BUBBLE -> {
            // Yumuşak eziliş: x büyürken y küçülür (iOS'taki scaleX/Y salınımı)
            val w = 1f + 0.09f * sin(t * (PI / 1.1).toFloat())
            val h = 1f - 0.09f * sin(t * (PI / 1.1).toFloat())
            withTransform({ scale(w, h, pivot = c) }) {
                drawCircle(Color.White.copy(alpha = 0.20f), r * 1.05f, c)
                drawCircle(Color.White.copy(alpha = 0.8f), r * 1.1f, c, style = Stroke(width = 1.5f * den))
            }
        }

        OrbStyle.Kind.HEART -> {
            // Kalp atışı: tık-tık … bekle (1.11 sn'lik döngü)
            val cyc = t % 1.11f
            val s = when {
                cyc < 0.12f -> 1f + 0.18f * (cyc / 0.12f)
                cyc < 0.28f -> 1.18f - 0.18f * ((cyc - 0.12f) / 0.16f)
                cyc < 0.38f -> 1f + 0.12f * ((cyc - 0.28f) / 0.10f)
                cyc < 0.56f -> 1.12f - 0.12f * ((cyc - 0.38f) / 0.18f)
                else -> 1f
            }
            scale(s, pivot = c) { drawPath(heartPath(c, r * 1.3f), Color(0xFFFF2D55)) }
        }

        OrbStyle.Kind.FIREFLY -> {
            drawCircle(Color(0xFF291F14), r * 0.75f, c)
            // Kuyruk yanıp söner: yan-sön-bekle döngüsü (2 sn)
            val cyc = t % 2f
            val a = when {
                cyc < 0.5f -> 1f - 0.85f * (cyc / 0.5f)
                cyc < 0.75f -> 0.15f
                cyc < 1.1f -> 0.15f + 0.85f * ((cyc - 0.75f) / 0.35f)
                else -> 1f
            }
            val tail = Offset(c.x, c.y + r * 0.65f)
            drawCircle(Color(0xFFBFFF66).copy(alpha = a * 0.4f), r * 1.3f, tail)
            drawCircle(Color(0xFFBFFF66).copy(alpha = a), r * 0.45f, tail)
        }

        OrbStyle.Kind.CLOUD -> {
            val puff = Color.White.copy(alpha = 0.95f)
            val bob = 3f * den * sin(t * (PI / 1.4).toFloat())
            drawCircle(puff, r * 0.85f, Offset(c.x - r * 0.55f, c.y + r * 0.15f))
            drawCircle(puff, r * 1.05f, Offset(c.x, c.y - r * 0.1f + bob))
            drawCircle(puff, r * 0.8f, Offset(c.x + r * 0.6f, c.y + r * 0.1f))
        }

        OrbStyle.Kind.MOON -> {
            // Hilal: dolu daireden ikinci bir daire "ısırılıyor". Isıran daire
            // zemin rengiyle boyanmıyor, katman maskesiyle çıkarılıyor ki tema
            // değişince hilal bozulmasın.
            val mr = r * 1.15f
            val layer = Rect(c.x - mr * 2, c.y - mr * 2, c.x + mr * 2, c.y + mr * 2)
            drawContext.canvas.saveLayer(layer, androidx.compose.ui.graphics.Paint())
            drawCircle(theme.orb, mr, c)
            drawCircle(
                Color.Transparent, r * 1.0f,
                Offset(c.x + r * 0.62f, c.y - r * 0.16f),
                blendMode = androidx.compose.ui.graphics.BlendMode.Clear
            )
            drawContext.canvas.restore()
        }

        OrbStyle.Kind.ATOM -> {
            // Elektron kendi yörüngesinde dönüyor: oyunun yaptığı şeyin küçüğü
            val orbitR = r * 1.5f
            drawOval(
                theme.accent.copy(alpha = 0.55f),
                topLeft = Offset(c.x - orbitR, c.y - orbitR * 0.4f),
                size = Size(orbitR * 2, orbitR * 0.8f),
                style = Stroke(width = 1.5f * den)
            )
            drawCircle(theme.orb, r * 0.62f, c)
            val a = t * 3.9f
            drawCircle(
                theme.accent, r * 0.3f,
                Offset(c.x + cos(a) * orbitR, c.y + sin(a) * orbitR * 0.4f)
            )
        }

        OrbStyle.Kind.NOVA -> {
            // Bütün yıldızları toplayanın küresi: patlayan bir yıldız
            val pulse = 1.05f + 0.13f * sin(t * (PI / 1.1).toFloat())
            rotate(t * 32f, c) {
                drawPath(starPath(c, r * 2.0f * pulse), theme.lumen.copy(alpha = 0.35f))
            }
            drawCircle(Color.White, r * 0.85f, c)
            drawCircle(theme.lumen, r * 0.85f, c, style = Stroke(width = 1.5f * den))
        }

        OrbStyle.Kind.PLANET -> {
            // Halkalı gezegen. Halka ARKADA tam elips, ÖNDE alt yarısı: küre
            // halkanın içinden geçiyormuş gibi duruyor. Tek elips çizmek
            // küreyi halkanın önüne yapıştırılmış gibi gösteriyordu.
            val tilt = -20f
            val rw = r * 3.2f
            val rh = r * 1.0f
            rotate(tilt, c) {
                drawOval(theme.lumen.copy(alpha = 0.75f),
                    topLeft = Offset(c.x - rw / 2f, c.y - rh / 2f),
                    size = Size(rw, rh), style = Stroke(width = 2.5f * den))
            }
            drawCircle(theme.orb, r, c)
            rotate(tilt, c) {
                drawArc(theme.lumen, 0f, 180f, false,
                    topLeft = Offset(c.x - rw / 2f, c.y - rh / 2f),
                    size = Size(rw, rh), style = Stroke(width = 2.5f * den))
            }
        }

        OrbStyle.Kind.BOLT -> {
            // Çakma: kısa parlama, uzun bekleme. Sürekli titreyen bir şimşek
            // şimşek değil, arızalı bir ampul olurdu.
            val cycle = (t * 0.9f) % 1f
            val flash = when {
                cycle < 0.06f -> 1f
                cycle < 0.14f -> 0.78f
                cycle < 0.20f -> 1f
                else -> 0.8f
            }
            drawPath(boltPath(c, r * 1.6f), theme.lumen.copy(alpha = flash))
            drawPath(boltPath(c, r * 1.6f), Color.White.copy(alpha = 0.8f),
                style = Stroke(width = 1f * den))
        }

        OrbStyle.Kind.DROPLET -> {
            // Damla + ondan yayılan halka: düşen damlanın suya değme anı
            val ripple = (t * 0.55f) % 1f
            drawCircle(theme.accent.copy(alpha = (1f - ripple) * 0.7f),
                r * 0.9f * (1f + ripple * 1.1f), c, style = Stroke(width = 1.5f * den))
            val squash = 1f + 0.09f * sin(t * (PI / 0.55f).toFloat())
            scale(1f / squash, squash, c) {
                drawPath(dropletPath(c, r * 1.1f), theme.accent)
                drawPath(dropletPath(c, r * 1.1f), Color.White.copy(alpha = 0.7f),
                    style = Stroke(width = 1f * den))
            }
            drawCircle(Color.White.copy(alpha = 0.85f), r * 0.22f,
                Offset(c.x - r * 0.33f, c.y - r * 0.1f))
        }

        OrbStyle.Kind.GHOST -> {
            // Süzülme: yukarı aşağı yumuşak salınım
            val float = sin(t * (PI / 0.8f).toFloat()) * 3.5f * den
            val gc = Offset(c.x, c.y + float)
            drawPath(ghostPath(gc, r * 1.15f), Color.White.copy(alpha = 0.92f))
            val eye = Color(0xFF1F2133)
            drawCircle(eye, r * 0.18f, Offset(gc.x - r * 0.38f, gc.y - r * 0.35f))
            drawCircle(eye, r * 0.18f, Offset(gc.x + r * 0.38f, gc.y - r * 0.35f))
        }

        OrbStyle.Kind.CHAMPION -> {
            // Altın taç + ters yönde dönen defne halkası. Köşeli siluet
            // diğer kürelerin hepsinden ayrışsın diye seçildi.
            val gold = Color(0xFFFFD159)
            drawCircle(gold.copy(alpha = 0.16f), r * 1.9f, c)
            val pulse = 1.02f + 0.06f * sin(t * (PI / 0.7f).toFloat())
            drawPath(crownPath(c, r * 2.6f * pulse, r * 1.9f * pulse), gold)
            rotate(-t * 72f, c) {
                drawCircle(gold.copy(alpha = 0.85f), r * 2.1f, c,
                    style = Stroke(width = 2f * den,
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(5f * den, 6f * den))))
            }
        }

        OrbStyle.Kind.CHRONO -> {
            // Kadran + akrep. Akrep zaman yavaşlarken gözle görülür şekilde
            // ağırlaşıyor: yeteneğin çalıştığını söyleyen en sessiz gösterge.
            drawCircle(theme.bgTop.copy(alpha = 0.9f), r * 1.35f, c)
            drawCircle(theme.accent, r * 1.35f, c, style = Stroke(width = 2f * den))
            val hand = -t * (360f / 3f)
            rotate(hand, c) {
                drawLine(theme.lumen, c, Offset(c.x, c.y - r * 1.05f),
                    strokeWidth = 1.6f * den, cap = StrokeCap.Round)
            }
            drawCircle(theme.lumen, r * 0.3f, c)

            // Dolum yayı: doluyken görünmüyor — her karede ekranda duran bir
            // gösterge, bir şey anlatmadığı sürece gürültüdür.
            val charge = engine.chronoCharge
            if (charge < 0.999f || engine.chronoSlowing) {
                val gr = r * 2.4f
                drawArc(
                    if (charge < 0.2f) theme.hazard else theme.lumen.copy(alpha = 0.9f),
                    -90f, -360f * charge, false,
                    topLeft = Offset(c.x - gr, c.y - gr), size = Size(gr * 2, gr * 2),
                    style = Stroke(width = 2.5f * den, cap = StrokeCap.Round)
                )
            }
        }

        OrbStyle.Kind.PHOTO -> {
            if (photo != null) {
                val pr = r * 1.6f
                val clip = Path().apply { addOval(Rect(c.x - pr, c.y - pr, c.x + pr, c.y + pr)) }
                clipPath(clip) {
                    val m = Matrix()
                    val scaleF = (pr * 2) / minOf(photo.width, photo.height)
                    drawImage(
                        photo,
                        dstOffset = androidx.compose.ui.unit.IntOffset(
                            (c.x - photo.width * scaleF / 2).toInt(),
                            (c.y - photo.height * scaleF / 2).toInt()
                        ),
                        dstSize = androidx.compose.ui.unit.IntSize(
                            (photo.width * scaleF).toInt(), (photo.height * scaleF).toInt()
                        )
                    )
                }
                drawCircle(theme.orb, pr, c, style = Stroke(width = 2f * den))
            } else {
                drawCircle(theme.orb, r, c)
            }
        }
    }

    // Dolum yayı — yavaşlatan BÖLÜMDE başka bir küreyle oynayan oyuncu için.
    // Chrono küresinin kendi çiziminde zaten var, o yüzden orada tekrar
    // çizilmiyor. Aynı yay, aynı yer, aynı renk: yeteneğin nereden geldiği
    // değişse de göstergesi değişmemeli.
    if (engine.usesChronoSlow && style.kind != OrbStyle.Kind.CHRONO) {
        val charge = engine.chronoCharge
        if (charge < 0.999f || engine.chronoSlowing) {
            val gr = r * 2.4f
            drawArc(
                if (charge < 0.2f) theme.hazard else theme.lumen.copy(alpha = 0.9f),
                -90f, -360f * charge, false,
                topLeft = Offset(c.x - gr, c.y - gr), size = Size(gr * 2, gr * 2),
                style = Stroke(width = 2.5f * den, cap = StrokeCap.Round)
            )
        }
    }
}

private fun DrawScope.drawBursts(engine: GameEngine, theme: Theme, den: Float) {
    for (b in engine.bursts) {
        if (b.age < 0f) continue   // gecikmeli kutlama parçası, sırası gelmedi
        val progress = (b.age / 0.6f).coerceIn(0f, 1f)
        val alpha = 1f - progress
        val spread = (12f + progress * 46f) * den
        val color = when (b.color) {
            GameEngine.FxColor.ACCENT -> theme.accent
            GameEngine.FxColor.LUMEN -> theme.lumen
            GameEngine.FxColor.HAZARD -> theme.hazard
            GameEngine.FxColor.GATE -> theme.gate
            GameEngine.FxColor.ORB -> theme.orb
        }
        for (k in 0 until b.count) {
            val angle = (2 * PI * k / b.count).toFloat()
            drawCircle(color.copy(alpha = alpha * 0.8f), 2.5f * den,
                Offset(b.x + cos(angle) * spread, b.y + sin(angle) * spread))
        }
    }
}

// MARK: Yollar (iOS starPath/heartPath/polygonPath karşılıkları)

private fun starPath(c: Offset, radius: Float): Path = starPath(c, radius, radius * 0.45f)

private fun starPath(c: Offset, outer: Float, inner: Float): Path {
    val path = Path()
    val points = 5
    for (i in 0 until points * 2) {
        val r = if (i % 2 == 0) outer else inner
        val a = i * PI.toFloat() / points - PI.toFloat() / 2
        val p = Offset(c.x + cos(a) * r, c.y + sin(a) * r)
        if (i == 0) path.moveTo(p.x, p.y) else path.lineTo(p.x, p.y)
    }
    path.close()
    return path
}

private fun polygonPath(c: Offset, sides: Int, radius: Float): Path {
    val path = Path()
    for (i in 0 until sides) {
        val a = i * 2 * PI.toFloat() / sides - PI.toFloat() / 2
        val p = Offset(c.x + cos(a) * radius, c.y + sin(a) * radius)
        if (i == 0) path.moveTo(p.x, p.y) else path.lineTo(p.x, p.y)
    }
    path.close()
    return path
}

/** Şimşek — iOS boltPath'inin karşılığı */
private fun boltPath(c: Offset, r: Float): Path = Path().apply {
    moveTo(c.x + r * 0.10f, c.y - r)
    lineTo(c.x - r * 0.55f, c.y + r * 0.12f)
    lineTo(c.x - r * 0.08f, c.y + r * 0.12f)
    lineTo(c.x - r * 0.18f, c.y + r)
    lineTo(c.x + r * 0.55f, c.y - r * 0.18f)
    lineTo(c.x + r * 0.06f, c.y - r * 0.18f)
    close()
}

/** Damla: sivri tepe, yuvarlak taban */
private fun dropletPath(c: Offset, r: Float): Path = Path().apply {
    moveTo(c.x, c.y - r * 1.25f)
    cubicTo(c.x + r * 0.85f, c.y - r * 0.15f, c.x + r, c.y + r * 0.30f, c.x, c.y + r)
    cubicTo(c.x - r, c.y + r * 0.30f, c.x - r * 0.85f, c.y - r * 0.15f, c.x, c.y - r * 1.25f)
    close()
}

/** Hayalet: kubbe gövde, dalgalı etek */
private fun ghostPath(c: Offset, r: Float): Path = Path().apply {
    moveTo(c.x - r, c.y + r * 0.75f)
    lineTo(c.x - r, c.y - r * 0.1f)
    cubicTo(c.x - r, c.y - r * 1.25f, c.x + r, c.y - r * 1.25f, c.x + r, c.y - r * 0.1f)
    lineTo(c.x + r, c.y + r * 0.75f)
    // Üç dalga: eteğin kendisi
    cubicTo(c.x + r * 0.66f, c.y + r * 1.15f, c.x + r * 0.66f, c.y + r * 0.45f,
            c.x + r * 0.33f, c.y + r * 0.85f)
    cubicTo(c.x + r * 0.10f, c.y + r * 1.15f, c.x - r * 0.10f, c.y + r * 1.15f,
            c.x - r * 0.33f, c.y + r * 0.85f)
    cubicTo(c.x - r * 0.66f, c.y + r * 0.45f, c.x - r * 0.66f, c.y + r * 1.15f,
            c.x - r, c.y + r * 0.75f)
    close()
}

/** Taç — şampiyon küresinin silueti */
private fun crownPath(c: Offset, w: Float, h: Float): Path = Path().apply {
    val left = c.x - w / 2f
    val right = c.x + w / 2f
    val bottom = c.y + h * 0.42f
    val top = c.y - h * 0.5f
    moveTo(left, bottom)
    lineTo(left, top + h * 0.18f)
    lineTo(left + w * 0.25f, top + h * 0.52f)
    lineTo(c.x, top)
    lineTo(right - w * 0.25f, top + h * 0.52f)
    lineTo(right, top + h * 0.18f)
    lineTo(right, bottom)
    close()
}

private fun heartPath(c: Offset, s: Float): Path {
    val path = Path()
    path.moveTo(c.x, c.y + s * 0.8f)
    path.cubicTo(c.x - s * 0.4f, c.y + s * 1.3f, c.x - s, c.y + s * 0.2f, c.x - s, c.y - s * 0.35f)
    path.arcTo(Rect(c.x - s, c.y - s * 0.85f, c.x, c.y + s * 0.15f), 180f, 180f, false)
    path.arcTo(Rect(c.x, c.y - s * 0.85f, c.x + s, c.y + s * 0.15f), 180f, 180f, false)
    path.cubicTo(c.x + s, c.y + s * 0.2f, c.x + s * 0.4f, c.y + s * 1.3f, c.x, c.y + s * 0.8f)
    path.close()
    return path
}

/**
 * Alev: yukarı sivrilen damla. sx/sy, iOS'taki scaleX/scaleY salınımının
 * karşılığı — alev yanarken enine/boyuna hafifçe oynar.
 * (Compose'da y aşağı arttığı için iOS'un tersine işaretler çevrilir.)
 */
internal fun flamePath(c: Offset, r: Float, sx: Float, sy: Float): Path {
    val rx = r * sx
    val ry = r * sy
    val baseY = c.y + ry * 0.15f
    val path = Path()
    path.moveTo(c.x, c.y - ry * 1.55f)
    path.cubicTo(
        c.x + rx * 0.5f, c.y - ry * 0.9f,
        c.x + rx, c.y - ry * 0.55f,
        c.x + rx, baseY
    )
    path.arcTo(Rect(c.x - rx, baseY - ry, c.x + rx, baseY + ry), 0f, 180f, false)
    path.cubicTo(
        c.x - rx, c.y - ry * 0.55f,
        c.x - rx * 0.5f, c.y - ry * 0.9f,
        c.x, c.y - ry * 1.55f
    )
    path.close()
    return path
}
