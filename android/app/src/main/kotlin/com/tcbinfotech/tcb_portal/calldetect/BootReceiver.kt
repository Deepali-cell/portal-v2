package com.tcbinfotech.tcb_portal.calldetect

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Restarts the persistent [CallDetectionService] after a reboot (or an app
 * update) so call detection keeps working without the user re-opening the app.
 *
 * Why this exists: on aggressive OEMs (Vivo / Oppo / Xiaomi) the manifest
 * PHONE_STATE receiver is NOT delivered to an app that is in the "stopped"
 * state - which is exactly where an app sits after a reboot until it is
 * launched once. Keeping a foreground service alive takes the app out of the
 * stopped state, so this receiver brings that service back up on boot.
 *
 * It only restarts the service when the user has actually turned call
 * detection ON (flag persisted by [DetectionPrefs]); otherwise it does
 * nothing, so non-sales users never get a background service.
 *
 * NOTE: BOOT_COMPLETED is still withheld from a force-stopped app, and OEM
 * "Autostart" must be enabled for it to fire on those phones. That part is
 * unavoidable from code and is handled by in-app guidance.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "TcbBootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.d(TAG, "onReceive action=$action")
        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                if (!DetectionPrefs.isEnabled(context)) {
                    Log.d(TAG, "Call detection is off - not starting service")
                    return
                }
                val svc = Intent(context, CallDetectionService::class.java).apply {
                    this.action = CallDetectionService.ACTION_START_PERSISTENT
                }
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(svc)
                    } else {
                        context.startService(svc)
                    }
                    Log.d(TAG, "Persistent CallDetectionService restarted after $action")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to restart service on boot: ${e.message}", e)
                }
            }
        }
    }
}
