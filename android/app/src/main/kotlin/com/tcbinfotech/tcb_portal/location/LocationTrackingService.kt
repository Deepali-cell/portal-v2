package com.tcbinfotech.tcb_portal.location

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.os.BatteryManager
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.tcbinfotech.tcb_portal.MainActivity
import com.tcbinfotech.tcb_portal.R

/**
 * Foreground service that streams fused-location updates to the Flutter side
 * via a broadcast Intent (picked up by LocationTrackingBridge in MainActivity).
 *
 * Started with ACTION_START, stopped with ACTION_STOP. While running the
 * user sees a persistent LOW-importance notification so they always know
 * their location is being uploaded.
 */
class LocationTrackingService : Service() {

    companion object {
        const val ACTION_START = "com.tcbinfotech.tcb_portal.location.START"
        const val ACTION_STOP = "com.tcbinfotech.tcb_portal.location.STOP"
        const val BROADCAST_PING = "com.tcbinfotech.tcb_portal.location.PING"

        // In-memory flag mirrored by isTracking() so Flutter can query.
        @JvmStatic
        var isRunning: Boolean = false
            private set

        private const val CHANNEL_ID = "location_tracking"
        private const val CHANNEL_NAME = "Location sharing"
        private const val NOTIF_ID = 4711

        // 10-min pings, min-distance 100 m. Locked with the user
        // 2026-08-26 (evening). Trades freshness for battery: a field
        // sales rep who moves rarely will burn far less battery, and
        // the last known position is always visible to the manager.
        private const val INTERVAL_MS = 600_000L
        private const val MIN_DISTANCE_M = 100f

        private const val TAG = "LocationTrackingSvc"
    }

    private lateinit var fused: FusedLocationProviderClient
    private var callback: LocationCallback? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        fused = LocationServices.getFusedLocationProviderClient(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelfSafely()
                return START_NOT_STICKY
            }
            else -> startTracking()
        }
        // STICKY so Android restarts us if killed — but only while our
        // Flutter side hasn't sent an explicit STOP.
        return START_STICKY
    }

    private fun startTracking() {
        ensureChannel()

        val notif = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIF_ID, notif)
        }
        isRunning = true

        val request = LocationRequest.Builder(Priority.PRIORITY_BALANCED_POWER_ACCURACY, INTERVAL_MS)
            .setMinUpdateDistanceMeters(MIN_DISTANCE_M)
            .setMinUpdateIntervalMillis(INTERVAL_MS / 2)
            .setWaitForAccurateLocation(false)
            .build()

        callback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                for (loc in result.locations) {
                    broadcastPing(loc)
                }
            }
        }

        try {
            fused.requestLocationUpdates(request, callback!!, Looper.getMainLooper())
        } catch (e: SecurityException) {
            // Permission not granted — Flutter should catch this via a
            // pre-flight check, but guard anyway.
            Log.w(TAG, "requestLocationUpdates SecurityException; stopping", e)
            stopSelfSafely()
        }
    }

    private fun broadcastPing(loc: Location) {
        val bm = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        val battery = try {
            bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1
        } catch (_: Throwable) { -1 }

        val i = Intent(BROADCAST_PING).apply {
            setPackage(packageName)
            putExtra("latitude", loc.latitude)
            putExtra("longitude", loc.longitude)
            putExtra("accuracy_m", loc.accuracy.toDouble())
            putExtra("speed_mps", if (loc.hasSpeed()) loc.speed.toDouble() else 0.0)
            putExtra("battery_level", battery)
            putExtra("recorded_at", loc.time) // epoch ms
        }
        sendBroadcast(i)
    }

    private fun stopSelfSafely() {
        try {
            callback?.let { fused.removeLocationUpdates(it) }
        } catch (_: Throwable) { /* ignore */ }
        callback = null
        isRunning = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun buildNotification(): android.app.Notification {
        val openApp = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPI = PendingIntent.getActivity(
            this, 0, openApp,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val stopIntent = Intent(this, LocationTrackingService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPI = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("TCB Portal: sharing your location")
            .setContentText("Your manager can see where you are while this is on.")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(openPI)
            .addAction(0, "Turn off", stopPI)
            .build()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val ch = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Persistent notification while your location is being shared with your manager."
            setShowBadge(false)
        }
        nm.createNotificationChannel(ch)
    }

    override fun onDestroy() {
        try {
            callback?.let { fused.removeLocationUpdates(it) }
        } catch (_: Throwable) {}
        isRunning = false
        super.onDestroy()
    }
}
