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
        engine.resize(size.width, size.height)
        if (engine.ringSpecs.isEmpty()) return@Canvas

        val t = engine.elapsed.toFloat()

        // Ölümde kısa yatay sarsıntı (iOS'taki shake)
        val shake = if (engine.shakeTime > 0f)
            sin(engine.shakeTime * 90f) * 8f * (engine.shakeTime / 0.16f)
        else 0f

        val camShift = if (engine.mode is GameMode.Endless) size.height / 2f - engine.cameraY else 0f

        drawStars(theme, t, camShift)

        translate(left = shake, top = camShift) {
            drawTrail(engine, theme, orbStyle)
            drawRings(engine, theme, t)
            drawLumens(engine, theme, t)
            drawAimLine(engine, theme)
            drawOrb(engine, theme, orbStyle, photoImage, t)
            drawBursts(engine, theme)
        }

        if (engine.tapHintVisible) drawTapHint(theme, t)
    }
}

/** Yavaşça yukarı süzülen soluk yıldız alanı (iOS'taki stars emitter'ı). */
private fun DrawScope.drawStars(theme: Theme, t: Float, camShift: Float) {
    for (i in 0 until 42) {
        // Deterministik dağılım: her yıldızın kendi konumu, hızı ve parıltısı
        val seed = i * 2654435761L
        val fx = ((seed shr 8) and 0xFFFF).toFloat() / 0xFFFF
        val fy = ((seed shr 24) and 0xFFFF).toFloat() / 0xFFFF
        val speed = 4f + fx * 6f
        val x = fx * size.width
        val y = (fy * size.height - t * speed + camShift * 0.3f).mod(size.height)
        val twinkle = 0.18f + 0.14f * sin(t * 0.8f + i)
        val r = 1.2f + fy * 2.2f
        drawCircle(theme.ring.copy(alpha = twinkle), r, Offset(x, y))
    }
}

private fun DrawScope.drawTrail(engine: GameEngine, theme: Theme, orbStyle: OrbStyle) {
    val comet = orbStyle.kind == OrbStyle.Kind.COMET
    val life = if (comet) 0.9f else 0.45f
    for (p in engine.trail) {
        val a = (1f - p.age / life).coerceIn(0f, 1f)
        if (a <= 0f) continue
        val r = (if (comet) 7f else 5f) * a
        drawCircle(theme.accent.copy(alpha = a * 0.45f), r * 2.2f, Offset(p.x, p.y))
        drawCircle(theme.accent.copy(alpha = a * 0.8f), r, Offset(p.x, p.y))
    }
}

private fun DrawScope.drawRings(engine: GameEngine, theme: Theme, t: Float) {
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

        // Öğreticide hedef bariz YEŞİL — "buraya atacaksın"
        val gateColor = if (isTutorial) Color(0xFF34C759) else theme.gate
        val color = if (spec.isGate) gateColor else theme.ring

        // Dış parıltı + çizginin kendisi
        drawCircle(color.copy(alpha = 0.22f), r, c,
            style = Stroke(width = if (spec.isGate) 16f else 11f))
        drawCircle(color.copy(alpha = 0.9f), r, c, style = Stroke(width = 3.5f))

        if (spec.isGate) {
            drawCircle(gateColor.copy(alpha = 0.10f), r, c)
            // Yavaşça dönen kesikli dış çember (14 sn'de tam tur)
            rotate(degrees = t * (360f / 14f), pivot = c) {
                drawCircle(
                    gateColor.copy(alpha = 0.7f), r + 12f, c,
                    style = Stroke(width = 2f,
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 10f)))
                )
            }
        }

        // Kırmızı tehlike yayları: parıltılı, yuvarlak uçlu
        val rot = t * spec.hazardRotationSpeed
        for (arc in spec.hazardArcs) {
            val startDeg = Math.toDegrees((arc.start + rot).toDouble()).toFloat()
            val sweepDeg = Math.toDegrees((arc.end - arc.start).toDouble()).toFloat()
            val box = Rect(cx - r, cy - r, cx + r, cy + r)
            drawArc(theme.hazard.copy(alpha = 0.30f), startDeg, sweepDeg, false,
                topLeft = box.topLeft, size = Size(box.width, box.height),
                style = Stroke(width = 15f, cap = StrokeCap.Round))
            drawArc(theme.hazard, startDeg, sweepDeg, false,
                topLeft = box.topLeft, size = Size(box.width, box.height),
                style = Stroke(width = 7f, cap = StrokeCap.Round))
        }

        // "Devam et ya da düş" — aktif halkada azalan süre yayı
        val attached = engine.orbState as? GameEngine.OrbState.Attached
        if (engine.dwellVisible && attached?.ring == i) {
            val frac = engine.dwellFraction
            val rr = r + 9f
            drawArc(
                if (frac < 0.3f) theme.hazard else theme.lumen.copy(alpha = 0.8f),
                -90f, 360f * frac, false,
                topLeft = Offset(cx - rr, cy - rr), size = Size(rr * 2, rr * 2),
                style = Stroke(width = 3f, cap = StrokeCap.Round)
            )
        }
    }
}

private fun DrawScope.drawLumens(engine: GameEngine, theme: Theme, t: Float) {
    for (i in engine.lumens.indices) {
        if (engine.lumenCollected[i]) continue
        val (x, y) = engine.lumenPoint(i)
        // Nabız: 0.8 sn'de büyü-parla, 0.8 sn'de söner (iOS ile aynı ritim)
        val phase = sin(t * (PI / 0.8).toFloat() + i * 1.3f)
        val s = 1.07f + 0.18f * phase
        val a = 0.87f + 0.13f * phase
        val c = Offset(x, y)
        drawCircle(theme.lumen.copy(alpha = 0.30f * a), 15f * s, c)
        drawCircle(theme.lumen.copy(alpha = a), 7f * s, c)
    }
}

/** Antrenman: küre O AN fırlatılırsa gideceği yönü gösteren kesikli çizgi. */
private fun DrawScope.drawAimLine(engine: GameEngine, theme: Theme) {
    if (!engine.isTutorial) return
    val s = engine.orbState as? GameEngine.OrbState.Attached ?: return
    val tx = -sin(s.angle) * s.direction
    val ty = cos(s.angle) * s.direction
    val len = size.width * 0.5f
    drawLine(
        Color.White.copy(alpha = 0.7f),
        start = Offset(engine.orbX, engine.orbY),
        end = Offset(engine.orbX + tx * len, engine.orbY + ty * len),
        strokeWidth = 3f,
        cap = StrokeCap.Round,
        pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 9f))
    )
}

/** Dokunuş ipucu: nabız gibi genişleyen halka + el simgesi (ilk fırlatmaya dek). */
private fun DrawScope.drawTapHint(theme: Theme, t: Float) {
    val c = Offset(size.width * 0.80f, size.height * 0.68f)
    val cycle = (t % 1.1f) / 1.1f
    drawCircle(Color.White.copy(alpha = 0.8f * (1f - cycle)), 34f * (1f + cycle), c,
        style = Stroke(width = 2f))
    val handPulse = 1f - 0.12f * ((sin(t * 7f) + 1f) / 2f)
    scale(handPulse, pivot = c) {
        drawCircle(Color.White, 12f, c)
        drawCircle(Color.White, 5f, Offset(c.x, c.y - 18f))
    }
}

// MARK: Küre — seçilen stile göre çizilir (iOS setupOrb'un karşılığı)

private fun DrawScope.drawOrb(
    engine: GameEngine, theme: Theme, style: OrbStyle, photo: ImageBitmap?, t: Float
) {
    if (!engine.orbVisible) return
    val c = Offset(engine.orbX, engine.orbY)
    val r = 9f   // orbRadius

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
            drawPath(p, Color.White, style = Stroke(width = 1.5f))
        }

        OrbStyle.Kind.COMET -> drawCircle(Color.White, r * 0.85f, c)

        OrbStyle.Kind.RAINBOW -> {
            val hue = ((t % 4f) / 4f) * 360f
            drawCircle(Color.hsv(hue, 0.7f, 1f), r, c)
        }

        OrbStyle.Kind.RING -> drawCircle(theme.orb, r * 1.15f, c, style = Stroke(width = 3.5f))

        OrbStyle.Kind.DIAMOND -> rotate(t * (360f / 4.5f), pivot = c) {
            val p = polygonPath(c, 4, r * 1.4f)
            drawPath(p, theme.accent)
            drawPath(p, Color.White, style = Stroke(width = 1.5f))
        }

        OrbStyle.Kind.FLAME -> {
            val s = 1.02f + 0.18f * sin(t * (PI / 0.35).toFloat())
            drawCircle(theme.hazard, r * s, c)
        }

        OrbStyle.Kind.PIXEL -> {
            val s = r * 1.7f
            drawRect(theme.gate, topLeft = Offset(c.x - s / 2, c.y - s / 2), size = Size(s, s))
            drawRect(Color.White, topLeft = Offset(c.x - s / 2, c.y - s / 2), size = Size(s, s),
                style = Stroke(width = 1f))
        }

        OrbStyle.Kind.BUBBLE -> {
            // Yumuşak eziliş: x büyürken y küçülür (iOS'taki scaleX/Y salınımı)
            val w = 1f + 0.09f * sin(t * (PI / 1.1).toFloat())
            val h = 1f - 0.09f * sin(t * (PI / 1.1).toFloat())
            withTransform({ scale(w, h, pivot = c) }) {
                drawCircle(Color.White.copy(alpha = 0.32f), r * 1.1f, c)
                drawCircle(Color.White.copy(alpha = 0.8f), r * 1.1f, c, style = Stroke(width = 1.5f))
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
            val bob = 3f * sin(t * (PI / 1.4).toFloat())
            drawCircle(puff, r * 0.85f, Offset(c.x - r * 0.55f, c.y + r * 0.15f))
            drawCircle(puff, r * 1.05f, Offset(c.x, c.y - r * 0.1f + bob))
            drawCircle(puff, r * 0.8f, Offset(c.x + r * 0.6f, c.y + r * 0.1f))
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
                drawCircle(theme.orb, pr, c, style = Stroke(width = 2f))
            } else {
                drawCircle(theme.orb, r, c)
            }
        }
    }
}

private fun DrawScope.drawBursts(engine: GameEngine, theme: Theme) {
    for (b in engine.bursts) {
        if (b.age < 0f) continue   // gecikmeli kutlama parçası, sırası gelmedi
        val progress = (b.age / 0.6f).coerceIn(0f, 1f)
        val alpha = 1f - progress
        val spread = 12f + progress * 46f
        val color = when (b.color) {
            GameEngine.FxColor.ACCENT -> theme.accent
            GameEngine.FxColor.LUMEN -> theme.lumen
            GameEngine.FxColor.HAZARD -> theme.hazard
            GameEngine.FxColor.GATE -> theme.gate
            GameEngine.FxColor.ORB -> theme.orb
        }
        for (k in 0 until b.count) {
            val angle = (2 * PI * k / b.count).toFloat()
            drawCircle(color.copy(alpha = alpha * 0.8f), 2.5f,
                Offset(b.x + cos(angle) * spread, b.y + sin(angle) * spread))
        }
    }
}

// MARK: Yollar (iOS starPath/heartPath/polygonPath karşılıkları)

private fun starPath(c: Offset, radius: Float): Path {
    val path = Path()
    val points = 5
    for (i in 0 until points * 2) {
        val r = if (i % 2 == 0) radius else radius * 0.45f
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
