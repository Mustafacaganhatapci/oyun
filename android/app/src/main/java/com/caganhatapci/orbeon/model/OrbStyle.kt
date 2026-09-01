package com.caganhatapci.orbeon.model

import com.caganhatapci.orbeon.R

/** Bir küre stilinin nasıl açıldığı. */
sealed class OrbUnlock {
    data object Free : OrbUnlock()
    /**
     * Toplam yıldız bu eşiği geçtiği anda KENDİLİĞİNDEN açılır. Yıldız
     * harcanmıyor: biriktirmek tek başına ilerleme, her eşik bir ödül.
     */
    data class Stars(val cost: Int) : OrbUnlock()
    data object Premium : OrbUnlock()
}

/**
 * Kürenin (oyuncu "karakterinin") görsel stili.
 * Bazıları ücretsiz, bazıları yıldızla alınır, biri premium — hepsi kozmetiktir.
 */
data class OrbStyle(
    val id: String,
    val nameRes: Int,
    val unlock: OrbUnlock,
    val kind: Kind
) {
    enum class Kind {
        CLASSIC, STAR, CRYSTAL, COMET, RAINBOW, RING,
        DIAMOND, FLAME, PIXEL, PHOTO, BUBBLE, HEART, FIREFLY, CLOUD,
        MOON, ATOM, NOVA
    }

    val isPremium: Boolean get() = unlock is OrbUnlock.Premium
    val starCost: Int? get() = (unlock as? OrbUnlock.Stars)?.cost

    companion object {
        // Eşikler kampanyanın TAMAMINA yayılıyor: sonuncusu 620, toplam 806.
        // Önce 420'de bitiyordu ve kampanyanın yarısından sonrası ödülsüz
        // kalıyordu — o oyuncular ana ekranda anlamsız bir "x / 806"
        // görüyordu. İlki 9'da: üç bölümü üçer yıldızla bitiren oyuncu ilk
        // ödülünü orada alır.
        val all = listOf(
            OrbStyle("classic", R.string.orb_light,   OrbUnlock.Free,        Kind.CLASSIC),
            OrbStyle("star",    R.string.orb_star,    OrbUnlock.Free,        Kind.STAR),
            OrbStyle("ring",    R.string.orb_ring,    OrbUnlock.Stars(9),    Kind.RING),
            OrbStyle("bubble",  R.string.orb_bubble,  OrbUnlock.Stars(20),   Kind.BUBBLE),
            OrbStyle("crystal", R.string.orb_crystal, OrbUnlock.Stars(35),   Kind.CRYSTAL),
            OrbStyle("pixel",   R.string.orb_pixel,   OrbUnlock.Stars(55),   Kind.PIXEL),
            OrbStyle("heart",   R.string.orb_heart,   OrbUnlock.Stars(80),   Kind.HEART),
            OrbStyle("comet",   R.string.orb_comet,   OrbUnlock.Stars(110),  Kind.COMET),
            OrbStyle("diamond", R.string.orb_diamond, OrbUnlock.Stars(150),  Kind.DIAMOND),
            OrbStyle("firefly", R.string.orb_firefly, OrbUnlock.Stars(220),  Kind.FIREFLY),
            OrbStyle("flame",   R.string.orb_flame,   OrbUnlock.Stars(320),  Kind.FLAME),
            OrbStyle("rainbow", R.string.orb_rainbow, OrbUnlock.Stars(450),  Kind.RAINBOW),
            OrbStyle("cloud",   R.string.orb_cloud,   OrbUnlock.Stars(620),  Kind.CLOUD),
            // 620'den sonra 186 yıldız ödülsüz kalıyordu
            OrbStyle("moon",    R.string.orb_moon,    OrbUnlock.Stars(690),  Kind.MOON),
            OrbStyle("atom",    R.string.orb_atom,    OrbUnlock.Stars(750),  Kind.ATOM),
            OrbStyle("nova",    R.string.orb_nova,    OrbUnlock.Stars(806),  Kind.NOVA),
            OrbStyle("photo",   R.string.orb_photo,   OrbUnlock.Premium,     Kind.PHOTO)
        )

        /** Yıldız eşiğiyle açılan stiller, eşiğe göre sıralı */
        val starLadder get() = all.filter { it.starCost != null }.sortedBy { it.starCost }

        /**
         * Verilen yıldız sayısıyla henüz açılmamış İLK küre ve kalan yıldız.
         * Hepsi açıldıysa null — ana ekran o zaman toplam sayacına döner.
         */
        fun nextLocked(totalStars: Int): Pair<OrbStyle, Int>? =
            starLadder.firstOrNull { (it.starCost ?: 0) > totalStars }
                ?.let { it to ((it.starCost ?: 0) - totalStars) }

        fun byId(id: String): OrbStyle = all.firstOrNull { it.id == id } ?: all[0]
    }
}
