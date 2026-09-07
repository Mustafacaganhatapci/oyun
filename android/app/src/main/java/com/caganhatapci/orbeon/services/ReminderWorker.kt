package com.caganhatapci.orbeon.services

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.caganhatapci.orbeon.MainActivity
import com.caganhatapci.orbeon.R

/**
 * Yerel hatırlatmayı ekrana düşüren iş.
 *
 * Sunucu istemiyor: WorkManager zamanı geldiğinde uygulamayı uyandırıp bunu
 * çalıştırıyor. Yarış hatırlatmasının metni koddan (yerelleştirilmiş),
 * güncelleme hatırlatmasınınki duyuru belgesinden geliyor.
 */
class ReminderWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {

    companion object {
        const val KEY_KIND = "kind"
        const val KEY_TITLE = "title"
        const val KEY_BODY = "body"
        const val KIND_RACE = "race"
        const val KIND_UPDATE = "update"
    }

    override fun doWork(): Result {
        val ctx = applicationContext
        // İzin sonradan çekilmiş olabilir. Bildirim göndermeye çalışmak
        // sessizce başarısız olur ama denememek daha dürüst.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return Result.success()

        val kind = inputData.getString(KEY_KIND) ?: KIND_RACE
        val title: String
        val body: String
        if (kind == KIND_UPDATE) {
            title = inputData.getString(KEY_TITLE) ?: return Result.success()
            body = inputData.getString(KEY_BODY) ?: return Result.success()
        } else {
            title = ctx.getString(R.string.race_closes_tomorrow)
            body = ctx.getString(R.string.race_one_run_enough)
        }

        val intent = Intent(ctx, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val pending = PendingIntent.getActivity(
            ctx, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(ctx, PushManager.CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(pending)
            .setAutoCancel(true)
            .build()

        runCatching {
            NotificationManagerCompat.from(ctx)
                .notify(if (kind == KIND_UPDATE) 2 else 1, notification)
        }
        return Result.success()
    }
}
