package com.tcbinfotech.tcb_portal.calldetect

import android.content.Context

/**
 * Tiny persisted flag shared between the Flutter side (via MainActivity's
 * method channel) and [BootReceiver]. Records whether the user has call
 * detection turned ON, so the boot receiver knows whether to bring the
 * persistent service back up after a reboot.
 *
 * Deliberately plain SharedPreferences (not the Flutter secure store) because
 * [BootReceiver] runs with no Flutter engine and must read this synchronously.
 */
object DetectionPrefs {
    private const val PREFS = "tcb_call_detect"
    private const val KEY_ENABLED = "persistent_enabled"

    fun setEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, enabled)
            .apply()
    }

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_ENABLED, false)
}
