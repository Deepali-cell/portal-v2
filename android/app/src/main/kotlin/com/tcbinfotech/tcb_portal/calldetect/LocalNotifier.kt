package com.tcbinfotech.tcb_portal.calldetect

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.tcbinfotech.tcb_portal.MainActivity

/**
 * Lightweight wrapper around Android NotificationManager so the Flutter
 * side can post user-facing alerts (e.g. "Call captured for Priya Patel"
 * or "AI summary ready") without depending on a heavy plugin.
 *
 * Notifications scoped to the device user (visibility=public is fine —
 * this is a single-user phone). Tap action opens MainActivity with an
 * extra `tcb.notif.deeplink` so the Dart side can route to the recording
 * detail screen.
 */
object LocalNotifier {

    private const val CHANNEL_ID = "tcb_call_summary"
    private const val CHANNEL_NAME = "Call Summary Alerts"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val ch = NotificationChannel(
            CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Alerts when a call is auto-captured or its AI summary is ready."
            enableLights(true)
            enableVibration(true)
        }
        nm.createNotificationChannel(ch)
    }

    fun post(
        context: Context,
        title: String,
        body: String,
        deeplink: String? = null,
        notifId: Int? = null,
    ): Int {
        ensureChannel(context)
        val id = notifId ?: System.currentTimeMillis().toInt()
        val openApp = PendingIntent.getActivity(
            context, id,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                if (!deeplink.isNullOrEmpty()) putExtra("tcb.notif.deeplink", deeplink)
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val n = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_call_mute)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(openApp)
            .build()
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.notify(id, n)
        return id
    }
}
