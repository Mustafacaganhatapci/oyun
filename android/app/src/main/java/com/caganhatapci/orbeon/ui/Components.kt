package com.caganhatapci.orbeon.ui

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.caganhatapci.orbeon.theme.Theme

/** Temanın dikey arka plan geçişi — tüm ekranların zemini. */
@Composable
fun ThemeBackground(theme: Theme, content: @Composable () -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(theme.bgTop, theme.bgBottom)))
    ) { content() }
}

/**
 * Oyunun tek düğme stili: hafif parlayan, yuvarlak köşeli kapsül.
 * `prominent` olan düğme dolgulu, diğerleri çerçevelidir.
 */
@Composable
fun GlowButton(
    text: String,
    color: Color,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    prominent: Boolean = false,
    enabled: Boolean = true,
    trailing: String? = null,
    onClick: () -> Unit
) {
    Box(
        modifier
            .fillMaxWidth()
            .alpha(if (enabled) 1f else 0.45f)
            .background(
                if (prominent) color else color.copy(alpha = 0.14f),
                RoundedCornerShape(18.dp)
            )
            .border(1.dp, color.copy(alpha = if (prominent) 0f else 0.55f), RoundedCornerShape(18.dp))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = if (trailing != null) Arrangement.SpaceBetween else Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (icon != null) {
                    Icon(
                        icon, null,
                        tint = if (prominent) Color.Black else color,
                        modifier = Modifier.size(18.dp)
                    )
                }
                Text(
                    text,
                    color = if (prominent) Color.Black else Color.White,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(start = if (icon != null) 8.dp else 0.dp)
                )
            }
            if (trailing != null) {
                Text(
                    trailing,
                    color = if (prominent) Color.Black else Color.White,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

/** Ekranların sol üstündeki geri düğmesi. */
@Composable
fun BackButton(onClick: () -> Unit) {
    Box(
        Modifier
            .size(44.dp)
            .background(Color.White.copy(alpha = 0.10f), CircleShape)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = Color.White)
    }
}

/** Kart zeminini tek yerden yönetir — tüm paneller aynı dokuya sahip olsun. */
@Composable
fun Card(
    modifier: Modifier = Modifier,
    corner: Int = 24,
    content: @Composable () -> Unit
) {
    Box(
        modifier
            .fillMaxWidth()
            .background(Color.White.copy(alpha = 0.05f), RoundedCornerShape(corner.dp))
            .padding(20.dp)
    ) { content() }
}

/** Sürekli yinelenen 0↔1 salınımı — nabız ve parıltı efektleri için. */
@Composable
fun pulse(durationMillis: Int = 1600): Float {
    val transition = rememberInfiniteTransition(label = "pulse")
    val value by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseValue"
    )
    return value
}
