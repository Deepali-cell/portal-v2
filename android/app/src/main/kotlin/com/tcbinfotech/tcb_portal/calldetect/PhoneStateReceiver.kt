package com.tcbinfotech.tcb_portal.calldetect

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager
import android.util.Log

/**
 * Broadcast receiver for android.intent.action.PHONE_STATE.
 *
 * Fires on every state change of the device's phone (idle → ringing →
 * offhook → idle). On any non-idle transition we start the
 * [CallDetectionService] which handles the heavy lifting + persists the
 * caller-info notification beyond the receiver's 10-second runtime cap.
 *
 * Android 10+ stripped EXTRA_INCOMING_NUMBER from PHONE_STATE for privacy.
 * The service will read the number from the CallLog provider with a small
 * delay; this receiver just hands off the state.
 */
class PhoneStateReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "TcbCallReceiver"
        // Last delivered state — class-level so we collapse the dual-fire
        // Android often emits per state change.
        @Volatile
        private var lastState: String? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return
        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        if (state == lastState) return
        lastState = state
        Log.d(TAG, "PHONE_STATE → $state")

        // Optional, may be null on Android 10+ for incoming calls.
        val intentNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)

        val svc = Intent(context, CallDetectionService::class.java).apply {
            action = when (state) {
                TelephonyManager.EXTRA_STATE_RINGING -> CallDetectionService.ACTION_RINGING
                TelephonyManager.EXTRA_STATE_OFFHOOK -> CallDetectionService.ACTION_OFFHOOK
                TelephonyManager.EXTRA_STATE_IDLE -> CallDetectionService.ACTION_IDLE
                else -> CallDetectionService.ACTION_IDLE
            }
            putExtra(CallDetectionService.EXTRA_NUMBER, intentNumber)
        }
        // Foreground service is required from Android 8+ when started outside
        // an active UI context.
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                context.startForegroundService(svc)
            } else {
                context.startService(svc)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start CallDetectionService: ${e.message}", e)
        }
    }
}
