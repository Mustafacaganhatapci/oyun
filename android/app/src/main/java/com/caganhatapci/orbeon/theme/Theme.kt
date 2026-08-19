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
    val accent: Color,
    /**
     * Renk körlüğü modunda üretilmiş bir tema mı? Oyun alanı bu bayrağa
     * bakarak renge ek olarak ŞEKİL ipucu da çiziyor (tehlike yaylarındaki
     * çentikler), çünkü tek başına renk hiçbir palette yeterli değil.
     */
    val isColorBlindSafe: Boolean = false
) {
    /**
     * "Bu tur yakmaz" durumundaki tehlike yayının rengi. Temanın `accent`
     * rengi kullanılamıyor: bazı temalarda (mercan) vurgu, tehlikenin
     * kendisine çok yakın bir somon tonu — yay silahlı mı değil mi
     * anlaşılmıyor. Tüm temaların halkası soğuk (mor/mavi/yeşil/beyaz)
     * olduğu için magenta hem halkayla hem kırmızıyla karışmıyor.
     */
    val hazardSafe: Color
        get() = if (isColorBlindSafe) Color(0.800f, 0.475f, 0.655f, 1f)
                else Color(0.839f, 0.361f, 0.941f, 1f)

    /**
     * Oyunun anlamı renge bağlı: yeşil kapı "git", kırmızı yay "ölürsün",
     * sarı yıldız "topla". En yaygın renk körlüğü tam bu kırmızı–yeşil
     * ayrımını siliyor. Bu mod açıkken zemin temanın kendisi olarak kalıyor,
     * ama OYNANIŞI belirleyen renkler Okabe–Ito paletinden sabit değerlerle
     * değiştiriliyor: bu palet protanopi, döteranopi ve tritanopide de
     * birbirinden ayrışır. Halka da nötr griye çekiliyor; yoksa kapının
     * mavisi bazı temaların mavi halkasıyla karışıyor.
     */
    val colorBlindSafe: Theme
        get() = copy(
            ring = Color(0.788f, 0.808f, 0.863f, 1f),      // nötr gri-mavi
            gate = Color(0.196f, 0.588f, 0.894f, 1f),      // doygun mavi
            orb = Color(1f, 1f, 1f, 1f),
            hazard = Color(0.902f, 0.400f, 0.055f, 1f),    // vermilyon
            lumen = Color(0.941f, 0.894f, 0.259f, 1f),     // sarı
            accent = Color(0f, 0.694f, 0.506f, 1f),        // mavimsi yeşil
            isColorBlindSafe = true
        )

    companion object {
        private fun c(r: Double, g: Double, b: Double) =
            Color(r.toFloat(), g.toFloat(), b.toFloat(), 1f)

        // Varsayılan tema. Arka plan bilerek DÜŞÜK doygunlukta: eski mor
        // (0.129, 0.043, 0.267) uzun oturumlarda göz yoruyordu.
        val nebula = Theme("nebula", R.string.theme_nebula, false,
            c(0.035,0.033,0.068), c(0.070,0.057,0.112), c(0.689,0.661,0.939),
            c(0.290,0.949,0.788), c(1.0,1.0,1.0), c(1.0,0.302,0.416),
            c(1.0,0.827,0.353), c(0.639,0.545,1.0))

        val gece = Theme("gece", R.string.theme_night, false,
            c(0.017,0.031,0.055), c(0.031,0.073,0.117), c(0.546,0.791,0.967),
            c(0.478,1.0,0.643), c(0.918,0.976,1.0), c(1.0,0.275,0.263),
            c(1.0,0.851,0.400), c(0.353,0.784,1.0))

        val safak = Theme("safak", R.string.theme_dawn, true,
            c(0.081,0.045,0.111), c(0.219,0.095,0.164), c(0.776,0.819,1.000),
            c(1.0,0.871,0.549), c(1.0,0.965,0.933), c(1.0,0.302,0.290),
            c(1.0,0.816,0.302), c(1.0,0.620,0.549))

        val orman = Theme("orman", R.string.theme_forest, true,
            c(0.019,0.061,0.052), c(0.044,0.125,0.095), c(0.628,0.921,0.724),
            c(0.451,0.902,1.0), c(0.949,1.0,0.949), c(1.0,0.290,0.235),
            c(1.0,0.851,0.400), c(0.478,0.918,0.643))

        val mercan = Theme("mercan", R.string.theme_coral, true,
            c(0.027,0.052,0.087), c(0.037,0.139,0.168), c(0.546,0.901,0.903),
            c(1.0,0.804,0.451), c(1.0,0.976,0.949), c(1.0,0.271,0.302),
            c(1.0,0.851,0.451), c(1.0,0.549,0.502))

        val aurora = Theme("aurora", R.string.theme_aurora, true,
            c(0.026,0.018,0.066), c(0.027,0.099,0.120), c(0.579,0.956,0.842),
            c(0.788,0.510,1.0), c(0.949,1.0,0.988), c(1.0,0.263,0.310),
            c(1.0,0.851,0.400), c(0.427,0.949,0.800))

        val neon = Theme("neon", R.string.theme_neon, true,
            c(0.013,0.013,0.033), c(0.037,0.022,0.065), c(0.480,0.936,1.000),
            c(0.451,1.0,0.549), c(1.0,1.0,1.0), c(1.0,0.153,0.353),
            c(1.0,0.902,0.251), c(0.851,0.353,1.0))

        val karbon = Theme("karbon", R.string.theme_carbon, true,
            c(0.024,0.024,0.030), c(0.064,0.064,0.073), c(0.967,0.967,1.000),
            c(0.302,1.0,0.502), c(0.549,0.847,1.0), c(1.0,0.200,0.200),
            c(1.0,0.800,0.200), c(0.600,0.651,0.749))

        val kraliyet = Theme("kraliyet", R.string.theme_royal, true,
            c(0.025,0.033,0.076), c(0.057,0.070,0.145), c(0.860,0.890,0.967),
            c(0.318,0.902,0.647), c(1.0,0.988,0.949), c(1.0,0.251,0.290),
            c(1.0,0.804,0.361), c(0.949,0.780,0.416))

        val sakura = Theme("sakura", R.string.theme_sakura, true,
            c(0.063,0.036,0.070), c(0.131,0.069,0.118), c(0.819,0.784,1.000),
            c(0.471,0.949,0.737), c(1.0,0.965,0.976), c(1.0,0.239,0.251),
            c(1.0,0.831,0.400), c(1.0,0.678,0.796))

        val all = listOf(nebula, gece, safak, orman, mercan, aurora,
                         neon, karbon, kraliyet, sakura)

        fun byId(id: String): Theme = all.firstOrNull { it.id == id } ?: nebula
    }
}
