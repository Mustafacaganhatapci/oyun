package com.caganhatapci.orbeon.theme

import androidx.compose.ui.graphics.Color
import com.caganhatapci.orbeon.R

/** Oyunun tüm renk kimliği tek yerden yönetilir. iOS sürümüyle aynı paletler. */
data class Theme(
    val id: String,
    /** Yerelleştirme kaynak kimliği */
    val nameRes: Int,
    val isPremium: Boolean,
    val bgTop: Color,
    val bgBottom: Color,
    val ring: Color,
    val gate: Color,
    val orb: Color,
    val hazard: Color,
    val lumen: Color,
    val accent: Color
) {
    companion object {
        private fun c(r: Double, g: Double, b: Double) =
            Color(r.toFloat(), g.toFloat(), b.toFloat(), 1f)

        val nebula = Theme("nebula", R.string.theme_nebula, false,
            c(0.055,0.043,0.161), c(0.129,0.043,0.267), c(0.478,0.408,0.933),
            c(0.290,0.949,0.788), c(1.0,1.0,1.0), c(1.0,0.302,0.416),
            c(1.0,0.827,0.353), c(0.639,0.545,1.0))

        val gece = Theme("gece", R.string.theme_night, false,
            c(0.020,0.051,0.102), c(0.031,0.122,0.216), c(0.302,0.678,0.949),
            c(0.478,1.0,0.643), c(0.918,0.976,1.0), c(1.0,0.275,0.263),
            c(1.0,0.851,0.400), c(0.353,0.784,1.0))

        val safak = Theme("safak", R.string.theme_dawn, true,
            c(0.141,0.063,0.204), c(0.396,0.129,0.278), c(0.655,0.722,1.0),
            c(1.0,0.871,0.549), c(1.0,0.965,0.933), c(1.0,0.302,0.290),
            c(1.0,0.816,0.302), c(1.0,0.620,0.549))

        val orman = Theme("orman", R.string.theme_forest, true,
            c(0.016,0.106,0.086), c(0.043,0.216,0.153), c(0.427,0.878,0.576),
            c(0.451,0.902,1.0), c(0.949,1.0,0.949), c(1.0,0.290,0.235),
            c(1.0,0.851,0.400), c(0.478,0.918,0.643))

        val mercan = Theme("mercan", R.string.theme_coral, true,
            c(0.031,0.086,0.161), c(0.020,0.239,0.302), c(0.302,0.847,0.851),
            c(1.0,0.804,0.451), c(1.0,0.976,0.949), c(1.0,0.271,0.302),
            c(1.0,0.851,0.451), c(1.0,0.549,0.502))

        val aurora = Theme("aurora", R.string.theme_aurora, true,
            c(0.043,0.024,0.129), c(0.016,0.169,0.216), c(0.353,0.933,0.757),
            c(0.788,0.510,1.0), c(0.949,1.0,0.988), c(1.0,0.263,0.310),
            c(1.0,0.851,0.400), c(0.427,0.949,0.800))

        val neon = Theme("neon", R.string.theme_neon, true,
            c(0.020,0.020,0.063), c(0.063,0.031,0.122), c(0.200,0.902,1.0),
            c(0.451,1.0,0.549), c(1.0,1.0,1.0), c(1.0,0.153,0.353),
            c(1.0,0.902,0.251), c(0.851,0.353,1.0))

        val karbon = Theme("karbon", R.string.theme_carbon, true,
            c(0.039,0.039,0.051), c(0.102,0.102,0.122), c(0.949,0.949,1.0),
            c(0.302,1.0,0.502), c(0.549,0.847,1.0), c(1.0,0.200,0.200),
            c(1.0,0.800,0.200), c(0.600,0.651,0.749))

        val kraliyet = Theme("kraliyet", R.string.theme_royal, true,
            c(0.035,0.051,0.145), c(0.082,0.110,0.271), c(0.784,0.831,0.949),
            c(0.318,0.902,0.647), c(1.0,0.988,0.949), c(1.0,0.251,0.290),
            c(1.0,0.804,0.361), c(0.949,0.780,0.416))

        val sakura = Theme("sakura", R.string.theme_sakura, true,
            c(0.110,0.051,0.125), c(0.231,0.098,0.204), c(0.722,0.667,1.0),
            c(0.471,0.949,0.737), c(1.0,0.965,0.976), c(1.0,0.239,0.251),
            c(1.0,0.831,0.400), c(1.0,0.678,0.796))

        val all = listOf(nebula, gece, safak, orman, mercan, aurora,
                         neon, karbon, kraliyet, sakura)

        fun byId(id: String): Theme = all.firstOrNull { it.id == id } ?: nebula
    }
}
