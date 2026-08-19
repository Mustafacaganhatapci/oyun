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
     * "Bu tur yakmaz" durumundaki tehlike yayının rengi. Kırmızının tam
     * karşıtı olduğu için yeşil, ama BİLEREK sönük: müsamahalı hâl ekranda
     * bağırmamalı, bağıran şey öldüren kırmızı olmalı. Parlak yeşilken bütün
     * yaylar aynı anda öne fırlıyor ve ekran okunmaz hâle geliyordu.
     *
     * Renk körlüğü modunda yeşil tam da işe yaramayan renk; orada
     * Okabe–Ito'nun mavimsi yeşiline geçiliyor.
     */
    val hazardSafe: Color
        get() = if (isColorBlindSafe) Color(0.176f, 0.478f, 0.404f, 1f)
                else Color(0.318f, 0.494f, 0.337f, 1f)

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
            c(0.047,0.046,0.071), c(0.082,0.074,0.110), c(0.570,0.560,0.663), c(0.347,0.725,0.633), c(0.940,0.940,0.940), c(0.703,0.302,0.368), c(0.777,0.678,0.405), c(0.519,0.473,0.697))

        val gece = Theme("gece", R.string.theme_night, false,
            c(0.029,0.039,0.057), c(0.056,0.084,0.113), c(0.534,0.625,0.690), c(0.472,0.772,0.567), c(0.869,0.915,0.935), c(0.695,0.278,0.272), c(0.782,0.696,0.437), c(0.397,0.609,0.715))

        val safak = Theme("safak", R.string.theme_dawn, true,
            c(0.095,0.069,0.116), c(0.220,0.138,0.184), c(0.659,0.675,0.742), c(0.789,0.715,0.530), c(0.936,0.908,0.882), c(0.699,0.299,0.292), c(0.774,0.668,0.373), c(0.730,0.543,0.508))

        val orman = Theme("orman", R.string.theme_forest, true,
            c(0.041,0.071,0.065), c(0.082,0.135,0.115), c(0.597,0.706,0.633), c(0.450,0.709,0.765), c(0.896,0.937,0.896), c(0.696,0.288,0.257), c(0.782,0.696,0.437), c(0.483,0.699,0.564))

        val mercan = Theme("mercan", R.string.theme_coral, true,
            c(0.048,0.066,0.091), c(0.085,0.152,0.171), c(0.560,0.691,0.692), c(0.776,0.664,0.461), c(0.937,0.918,0.896), c(0.695,0.277,0.295), c(0.783,0.698,0.468), c(0.715,0.493,0.470))

        val aurora = Theme("aurora", R.string.theme_aurora, true,
            c(0.034,0.028,0.062), c(0.061,0.108,0.122), c(0.588,0.727,0.685), c(0.612,0.452,0.734), c(0.897,0.938,0.928), c(0.694,0.271,0.298), c(0.782,0.696,0.437), c(0.465,0.721,0.648))

        val neon = Theme("neon", R.string.theme_neon, true,
            c(0.018,0.018,0.033), c(0.041,0.031,0.060), c(0.541,0.709,0.733), c(0.452,0.767,0.508), c(0.940,0.940,0.940), c(0.680,0.193,0.308), c(0.785,0.729,0.355), c(0.608,0.362,0.681))

        val karbon = Theme("karbon", R.string.theme_carbon, true,
            c(0.032,0.032,0.036), c(0.077,0.077,0.083), c(0.795,0.795,0.807), c(0.354,0.755,0.469), c(0.548,0.786,0.908), c(0.682,0.223,0.223), c(0.769,0.654,0.309), c(0.507,0.532,0.581))

        val kraliyet = Theme("kraliyet", R.string.theme_royal, true,
            c(0.039,0.044,0.075), c(0.078,0.087,0.136), c(0.719,0.730,0.758), c(0.354,0.690,0.543), c(0.938,0.929,0.897), c(0.692,0.262,0.284), c(0.774,0.661,0.407), c(0.726,0.643,0.463))

        val sakura = Theme("sakura", R.string.theme_sakura, true,
            c(0.073,0.054,0.078), c(0.137,0.096,0.128), c(0.672,0.659,0.738), c(0.463,0.737,0.615), c(0.937,0.909,0.918), c(0.689,0.252,0.259), c(0.779,0.682,0.434), c(0.750,0.592,0.650))

        val all = listOf(nebula, gece, safak, orman, mercan, aurora,
                         neon, karbon, kraliyet, sakura)

        fun byId(id: String): Theme = all.firstOrNull { it.id == id } ?: nebula
    }
}
