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
     * "Bu tur yakmaz" durumundaki tehlike yayının rengi: kırmızının karşıtı
     * olduğu için yeşil, ama BİLEREK sönük ve halkadan bir tık koyu. Tek vurgu
     * dilinde ekranın tek doygun rengi tehlike kırmızısı olmalı; müsamahalı
     * hâl fark edilir ama bağırmaz.
     *
     * Renk körlüğü modunda yeşil tam da işe yaramayan renk; orada
     * Okabe–Ito'nun mavimsi yeşiline geçiliyor.
     */
    val hazardSafe: Color
        get() = if (isColorBlindSafe) Color(0.243f, 0.435f, 0.396f, 1f)
                else Color(0.325f, 0.463f, 0.345f, 1f)

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

        // TEK VURGU dili: halkalar, zemin ve küre nötr; ekrandaki TEK doygun
        // renk tehlike kırmızısı, en parlak şey de hedef kapısı. Anlam taşıyan
        // üç renk (kapı ≈ beyaz, tehlike kırmızı, yıldız altın) bütün
        // temalarda AYNI — tema değiştirmek oynanışın dilini değiştirmiyor.

        // Varsayılan tema. Menekşe-gri.
        val nebula = Theme("nebula", R.string.theme_nebula, false,
            c(0.048,0.047,0.061), c(0.094,0.089,0.112), c(0.503,0.499,0.540), c(0.829,0.955,0.925), c(0.941,0.945,0.953), c(0.820,0.286,0.357), c(0.710,0.580,0.314), c(0.453,0.433,0.531))

        // Soğuk mavi-gri.
        val gece = Theme("gece", R.string.theme_night, false,
            c(0.043,0.050,0.062), c(0.078,0.096,0.115), c(0.478,0.512,0.537), c(0.857,0.949,0.886), c(0.941,0.945,0.953), c(0.820,0.286,0.357), c(0.710,0.580,0.314), c(0.385,0.471,0.513))

        // Gül-gri, hafif sıcak.
        val safak = Theme("safak", R.string.theme_dawn, true,
            c(0.053,0.045,0.060), c(0.109,0.084,0.098), c(0.499,0.504,0.527), c(0.934,0.914,0.862), c(0.941,0.945,0.953), c(0.820,0.286,0.357), c(0.710,0.580,0.314), c(0.501,0.430,0.417))

        // Yeşile çalan gri.
        val orman = Theme("orman", R.string.theme_forest, true,
            c(0.040,0.053,0.051), c(0.078,0.101,0.092), c(0.482,0.519,0.494), c(0.855,0.936,0.954), c(0.941,0.945,0.953), c(0.820,0.286,0.357), c(0.710,0.580,0.314), c(0.401,0.479,0.430))

        // Deniz grisi.
        val mercan = Theme("mercan", R.string.theme_coral, true,
            c(0.042,0.050,0.061), c(0.074,0.100,0.107), c(0.473,0.519,0.519), c(0.944,0.911,0.850), c(0.941,0.945,0.953), c(0.820,0.286,0.357), c(0.710,0.580,0.314), c(0.514,0.424,0.415))

        // Mor-yeşil arası soğuk gri.
        val aurora = Theme("aurora", R.string.theme_aurora, true,
            c(0.049,0.044,0.072), c(0.075,0.100,0.107), c(0.474,0.520,0.506), c(0.944,0.884,0.990), c(0.941,0.945,0.953), c(0.820,0.286,0.357), c(0.710,0.580,0.314), c(0.389,0.480,0.454))

        // En koyu zemin, mor-gri halka.
        val neon = Theme("neon", R.string.theme_neon, true,
            c(0.047,0.047,0.067), c(0.098,0.084,0.124), c(0.464,0.521,0.530), c(0.854,0.953,0.872), c(0.941,0.945,0.953), c(0.820,0.286,0.357), c(0.710,0.580,0.314), c(0.515,0.398,0.550))

        // Tamamen nötr gri — hiç renk sapması yok.
        val karbon = Theme("karbon", R.string.theme_carbon, true,
            c(0.049,0.049,0.052), c(0.093,0.093,0.097), c(0.505,0.505,0.508), c(0.831,0.965,0.869), c(0.941,0.945,0.953), c(0.820,0.286,0.357), c(0.710,0.580,0.314), c(0.440,0.451,0.472))

        // Gece mavisine çalan gri.
        val kraliyet = Theme("kraliyet", R.string.theme_royal, true,
            c(0.045,0.048,0.066), c(0.086,0.091,0.119), c(0.502,0.505,0.514), c(0.837,0.955,0.904), c(0.941,0.945,0.953), c(0.820,0.286,0.357), c(0.710,0.580,0.314), c(0.477,0.449,0.386))

        // Erik-gri, yumuşak.
        val sakura = Theme("sakura", R.string.theme_sakura, true,
            c(0.054,0.045,0.056), c(0.104,0.086,0.100), c(0.505,0.501,0.527), c(0.858,0.944,0.906), c(0.941,0.945,0.953), c(0.820,0.286,0.357), c(0.710,0.580,0.314), c(0.486,0.431,0.451))

        val all = listOf(nebula, gece, safak, orman, mercan, aurora,
                         neon, karbon, kraliyet, sakura)

        fun byId(id: String): Theme = all.firstOrNull { it.id == id } ?: nebula
    }
}
