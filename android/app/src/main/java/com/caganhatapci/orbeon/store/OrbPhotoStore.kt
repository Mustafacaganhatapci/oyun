package com.caganhatapci.orbeon.store

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import java.io.File

/**
 * Foto kürenin resmi — premium özelliği. Seçilen görsel uygulamanın kendi
 * deposuna küçültülerek kopyalanır; galeriye kalıcı erişim izni gerekmez.
 */
object OrbPhotoStore {
    private const val FILE = "orb_photo.png"

    fun file(context: Context): File = File(context.filesDir, FILE)

    fun load(context: Context): Bitmap? {
        val f = file(context)
        if (!f.exists()) return null
        return runCatching { BitmapFactory.decodeFile(f.absolutePath) }.getOrNull()
    }

    /** Galeriden seçilen görseli 256px kareye küçültüp kaydeder. */
    fun save(context: Context, uri: Uri): Boolean = runCatching {
        val input = context.contentResolver.openInputStream(uri) ?: return false
        val raw = input.use { BitmapFactory.decodeStream(it) } ?: return false
        val side = minOf(raw.width, raw.height)
        val square = Bitmap.createBitmap(raw, (raw.width - side) / 2, (raw.height - side) / 2, side, side)
        val scaled = Bitmap.createScaledBitmap(square, 256, 256, true)
        file(context).outputStream().use { scaled.compress(Bitmap.CompressFormat.PNG, 95, it) }
        true
    }.getOrDefault(false)
}
