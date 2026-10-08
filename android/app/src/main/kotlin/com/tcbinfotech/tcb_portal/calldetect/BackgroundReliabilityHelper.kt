package com.tcbinfotech.tcb_portal.calldetect

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log

/**
 * Keeps background call detection reliable on every Android brand.
 *
 * Two OS-level things put a background service to sleep and stop the
 * PHONE_STATE broadcast from ever reaching us:
 *   1. Battery optimization (Doze) - standard AOSP, same on all brands.
 *   2. OEM "Autostart" / "Auto-launch" managers - Xiaomi, Vivo, Oppo, Realme,
 *      Huawei, Samsung, OnePlus, etc. each hide this in their own settings
 *      screen. There is NO public API to toggle it, so the best we can do is
 *      open the right screen and let the user flip it.
 *
 * This helper is brand-agnostic: the battery part is pure AOSP, and the
 * autostart part tries a list of known OEM intents and falls back to the app
 * details page (which every phone has) if none resolve.
 */
object BackgroundReliabilityHelper {

    private const val TAG = "TcbBgReliability"

    /** True if the app is already exempt from Doze battery optimization. */
    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            ?: return false
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    /**
     * Opens the system dialog that asks the user to exempt this app from
     * battery optimization. AOSP - identical on every brand.
     */
    fun requestIgnoreBatteryOptimizations(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val intent = Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:${context.packageName}"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.w(TAG, "battery-opt request failed, opening list: ${e.message}")
            openBatteryOptimizationSettings(context)
        }
    }

    private fun openBatteryOptimizationSettings(context: Context) {
        try {
            context.startActivity(
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (e: Exception) {
            openAppDetails(context)
        }
    }

    // Known OEM autostart / background-management screens. Tried in order; the
    // first that resolves on this device wins. Covers the major brands; any
    // brand not listed falls back to the standard app-details page.
    private val OEM_AUTOSTART_INTENTS: List<ComponentName> = listOf(
        // Xiaomi / MIUI / HyperOS / POCO / Redmi
        ComponentName("com.miui.securitycenter",
            "com.miui.permcenter.autostart.AutoStartManagementActivity"),
        // Oppo / ColorOS
        ComponentName("com.coloros.safecenter",
            "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
        ComponentName("com.coloros.safecenter",
            "com.coloros.safecenter.startupapp.StartupAppListActivity"),
        ComponentName("com.oppo.safe",
            "com.oppo.safe.permission.startup.StartupAppListActivity"),
        // Vivo / iQOO (FuntouchOS / OriginOS)
        ComponentName("com.vivo.permissionmanager",
            "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
        ComponentName("com.iqoo.secure",
            "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
        ComponentName("com.iqoo.secure",
            "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"),
        // Realme (ColorOS based)
        ComponentName("com.coloros.safecenter",
            "com.coloros.safecenter.permission.startupapp.StartupAppListActivity"),
        // Huawei / Honor
        ComponentName("com.huawei.systemmanager",
            "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
        ComponentName("com.huawei.systemmanager",
            "com.huawei.systemmanager.optimize.process.ProtectActivity"),
        // Samsung (One UI battery/device care)
        ComponentName("com.samsung.android.lool",
            "com.samsung.android.sm.ui.battery.BatteryActivity"),
        ComponentName("com.samsung.android.sm",
            "com.samsung.android.sm.ui.battery.BatteryActivity"),
        // OnePlus (OxygenOS)
        ComponentName("com.oneplus.security",
            "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"),
        // Letv / Meizu / Asus omitted for brevity - fall back to app details.
    )

    /**
     * Opens the device's autostart / background-launch manager so the user can
     * allow this app to start on its own. Returns true if some settings screen
     * was opened (an OEM one or the app-details fallback).
     */
    fun openAutoStartSettings(context: Context): Boolean {
        val pm = context.packageManager
        for (cn in OEM_AUTOSTART_INTENTS) {
            try {
                val intent = Intent().apply {
                    component = cn
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                // Only launch if the component actually exists on this device.
                if (intent.resolveActivity(pm) != null) {
                    context.startActivity(intent)
                    Log.d(TAG, "opened autostart screen: $cn")
                    return true
                }
            } catch (e: Exception) {
                Log.w(TAG, "autostart intent $cn failed: ${e.message}")
            }
        }
        // No OEM manager on this brand (stock Android, Motorola, Nokia, Pixel,
        // etc. don't kill background apps) - open app details as a safe default.
        openAppDetails(context)
        return true
    }

    private fun openAppDetails(context: Context) {
        try {
            context.startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:${context.packageName}"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (e: Exception) {
            context.startActivity(
                Intent(Settings.ACTION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }
}
