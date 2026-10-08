package com.tcbinfotech.tcb_portal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.util.Log
import com.tcbinfotech.tcb_portal.calldetect.BackgroundReliabilityHelper
import com.tcbinfotech.tcb_portal.calldetect.CallDetectBridge
import com.tcbinfotech.tcb_portal.calldetect.CallDetectionService
import com.tcbinfotech.tcb_portal.calldetect.DetectionPrefs
import com.tcbinfotech.tcb_portal.calldetect.LocalNotifier
import com.tcbinfotech.tcb_portal.location.LocationTrackingService
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by the local_auth plugin (biometrics).
class MainActivity : FlutterFragmentActivity() {

    companion object {
        const val CALL_DETECT_CHANNEL = "tcb_portal/call_detect"
        const val LOCATION_CHANNEL = "tcb_portal/location_tracking"
        const val DEEPLINK_EXTRA = "tcb.notif.deeplink"
    }

    // Location channel + broadcast receiver that pipes native pings into Dart.
    private var locationChannel: MethodChannel? = null
    private var locationReceiver: BroadcastReceiver? = null

    // Most-recent deeplink received via Intent extra. Set on app cold-start +
    // every onNewIntent (warm tap from background). Flutter polls it on its
    // post-frame callback so we don't lose deeplinks fired before the
    // MethodChannel is alive.
    @Volatile
    private var pendingDeeplink: String? = null
    private var deeplinkChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Capture deeplink from the launch intent (cold-start case).
        val coldDeeplink = intent?.getStringExtra(DEEPLINK_EXTRA)
        Log.i("TcbDeeplink", "onCreate cold-start extra=$coldDeeplink")
        if (!coldDeeplink.isNullOrBlank()) {
            pendingDeeplink = coldDeeplink
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Warm-start: user tapped a notification while the app was already
        // running. Forward the extra to Flutter immediately if the channel
        // is alive; otherwise stash it for the next poll.
        setIntent(intent)
        val deeplink = intent.getStringExtra(DEEPLINK_EXTRA)
        Log.i("TcbDeeplink", "onNewIntent warm-tap extra=$deeplink channelAlive=${deeplinkChannel != null}")
        if (!deeplink.isNullOrBlank()) {
            pendingDeeplink = deeplink
            deeplinkChannel?.invokeMethod(
                "onDeeplink", mapOf("deeplink" to deeplink)
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CALL_DETECT_CHANNEL,
        )
        deeplinkChannel = channel
        // Wire native → Flutter so the foreground service can push call
        // detection events up to the Dart side.
        CallDetectBridge.attach(channel)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "ping" -> result.success("pong")
                "postLocalNotification" -> {
                    val args = call.arguments as? Map<*, *>
                    val title = args?.get("title") as? String ?: "TCB Portal"
                    val body = args?.get("body") as? String ?: ""
                    val deeplink = args?.get("deeplink") as? String
                    val id = (args?.get("id") as? Number)?.toInt()
                    val notifId = LocalNotifier.post(
                        context = this,
                        title = title,
                        body = body,
                        deeplink = deeplink,
                        notifId = id,
                    )
                    result.success(notifId)
                }
                "consumePendingDeeplink" -> {
                    val d = pendingDeeplink
                    pendingDeeplink = null
                    Log.i("TcbDeeplink", "consumePendingDeeplink → $d")
                    result.success(d)
                }
                // ---- Background reliability (all Android brands) ----------
                "startPersistentDetection" -> {
                    DetectionPrefs.setEnabled(this, true)
                    val i = Intent(this, CallDetectionService::class.java).apply {
                        action = CallDetectionService.ACTION_START_PERSISTENT
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(i)
                    } else {
                        startService(i)
                    }
                    result.success(true)
                }
                "stopPersistentDetection" -> {
                    DetectionPrefs.setEnabled(this, false)
                    val i = Intent(this, CallDetectionService::class.java).apply {
                        action = CallDetectionService.ACTION_STOP_PERSISTENT
                    }
                    startService(i)
                    result.success(true)
                }
                "isPersistentRunning" ->
                    result.success(CallDetectionService.isRunning)
                "isIgnoringBatteryOptimizations" ->
                    result.success(
                        BackgroundReliabilityHelper
                            .isIgnoringBatteryOptimizations(this),
                    )
                "requestIgnoreBatteryOptimizations" -> {
                    BackgroundReliabilityHelper
                        .requestIgnoreBatteryOptimizations(this)
                    result.success(true)
                }
                "openAutoStartSettings" ->
                    result.success(
                        BackgroundReliabilityHelper.openAutoStartSettings(this),
                    )
                else -> result.notImplemented()
            }
        }

        // --- Location tracking bridge -----------------------------------
        val locChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LOCATION_CHANNEL,
        )
        locationChannel = locChannel
        locChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val i = Intent(this, LocationTrackingService::class.java).apply {
                        action = LocationTrackingService.ACTION_START
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(i)
                    } else {
                        startService(i)
                    }
                    result.success(true)
                }
                "stopService" -> {
                    val i = Intent(this, LocationTrackingService::class.java).apply {
                        action = LocationTrackingService.ACTION_STOP
                    }
                    startService(i)
                    result.success(true)
                }
                "isRunning" -> result.success(LocationTrackingService.isRunning)
                else -> result.notImplemented()
            }
        }
        // Receive ping broadcasts from the foreground service and forward to Dart.
        val recv = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != LocationTrackingService.BROADCAST_PING) return
                val payload = mapOf(
                    "latitude" to intent.getDoubleExtra("latitude", 0.0),
                    "longitude" to intent.getDoubleExtra("longitude", 0.0),
                    "accuracy_m" to intent.getDoubleExtra("accuracy_m", 0.0),
                    "speed_mps" to intent.getDoubleExtra("speed_mps", 0.0),
                    "battery_level" to intent.getIntExtra("battery_level", -1),
                    "recorded_at" to intent.getLongExtra("recorded_at", 0L),
                )
                locationChannel?.invokeMethod("onLocationUpdate", payload)
            }
        }
        locationReceiver = recv
        val filter = IntentFilter(LocationTrackingService.BROADCAST_PING)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(recv, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            // Pre-13 dynamic receivers are exported: require our own
            // signature permission so other apps cannot inject fake pings.
            registerReceiver(recv, filter, "$packageName.permission.LOCATION_PING", null)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        CallDetectBridge.detach()
        deeplinkChannel = null
        try {
            locationReceiver?.let { unregisterReceiver(it) }
        } catch (_: Throwable) {}
        locationReceiver = null
        locationChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
