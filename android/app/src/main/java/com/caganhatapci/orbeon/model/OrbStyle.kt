package com.caganhatapci.orbeon.model

import com.caganhatapci.orbeon.R

/** Bir küre stilinin nasıl açıldığı. */
sealed class OrbUnlock {
    data object Free : OrbUnlock()
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
        DIAMOND, FLAME, PIXEL, PHOTO, BUBBLE, HEART, FIREFLY, CLOUD
    }

    val isPremium: Boolean get() = unlock is OrbUnlock.Premium
    val starCost: Int? get() = (unlock as? OrbUnlock.Stars)?.cost

    companion object {
        val all = listOf(
            OrbStyle("classic", R.string.orb_light,   OrbUnlock.Free,        Kind.CLASSIC),
            OrbStyle("star",    R.string.orb_star,    OrbUnlock.Free,        Kind.STAR),
            OrbStyle("ring",    R.string.orb_ring,    OrbUnlock.Stars(15),   Kind.RING),
            OrbStyle("bubble",  R.string.orb_bubble,  OrbUnlock.Stars(20),   Kind.BUBBLE),
            OrbStyle("crystal", R.string.orb_crystal, OrbUnlock.Stars(25),   Kind.CRYSTAL),
            OrbStyle("pixel",   R.string.orb_pixel,   OrbUnlock.Stars(40),   Kind.PIXEL),
            OrbStyle("heart",   R.string.orb_heart,   OrbUnlock.Stars(45),   Kind.HEART),
            OrbStyle("comet",   R.string.orb_comet,   OrbUnlock.Stars(55),   Kind.COMET),
            OrbStyle("diamond", R.string.orb_diamond, OrbUnlock.Stars(75),   Kind.DIAMOND),
            OrbStyle("firefly", R.string.orb_firefly, OrbUnlock.Stars(90),   Kind.FIREFLY),
            OrbStyle("flame",   R.string.orb_flame,   OrbUnlock.Stars(100),  Kind.FLAME),
            OrbStyle("rainbow", R.string.orb_rainbow, OrbUnlock.Stars(130),  Kind.RAINBOW),
            OrbStyle("cloud",   R.string.orb_cloud,   OrbUnlock.Stars(150),  Kind.CLOUD),
            OrbStyle("photo",   R.string.orb_photo,   OrbUnlock.Premium,     Kind.PHOTO)
        )

        /** Yıldızla satın alınabilen stiller (mağazada listelenir) */
        val starPurchasable get() = all.filter { it.starCost != null }

        fun byId(id: String): OrbStyle = all.firstOrNull { it.id == id } ?: all[0]
    }
}
