package com.tcbinfotech.tcb_portal.calldetect

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.database.Cursor
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.CallLog
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.tcbinfotech.tcb_portal.MainActivity

/**
 * Foreground service that lives for the duration of a phone call. Responsible
 * for:
 *   1. Resolving the incoming/outgoing number (CallLog lookup with a 600ms
 *      delay because Android 10+ scrubs EXTRA_INCOMING_NUMBER from the
 *      broadcast).
 *   2. Notifying the Flutter side via [CallDetectBridge] so the app can call
 *      its lookup_by_phone backend and resolve the caller's CRM identity.
 *   3. Posting a foreground-service notification (visible while the call is
 *      active) — Android requires this for any service started outside an
 *      active UI context. Tap → opens the app.
 *   4. On call end (IDLE state), staying alive briefly so the
 *      recording-folder scan (D.2.4 — future) can pick up the OEM-written
 *      MP3 before the service is torn down.
 *
 * No overlay window yet — that's D.2.3.
 * No recording fetch yet — that's D.2.4.
 * No AI summary yet — that's D.2.5.
 *
 * This file is the D.2.2 minimum viable: detection + notification + Flutter
 * bridge.
 */
class CallDetectionService : Service() {

    companion object {
        private const val TAG = "TcbCallSvc"
        const val ACTION_RINGING = "tcb.call.RINGING"
        const val ACTION_OFFHOOK = "tcb.call.OFFHOOK"
        const val ACTION_IDLE = "tcb.call.IDLE"
        // Persistent mode: keep the service (and therefore the app process)
        // alive between calls so the manifest PHONE_STATE receiver still fires
        // on OEMs that withhold broadcasts from a "stopped" app (Vivo/Oppo/…).
        const val ACTION_START_PERSISTENT = "tcb.call.START_PERSISTENT"
        const val ACTION_STOP_PERSISTENT = "tcb.call.STOP_PERSISTENT"
        const val EXTRA_NUMBER = "tcb.call.number"

        private const val CHANNEL_ID = "tcb_call_detection"
        private const val FG_NOTIF_ID = 9101
        private const val EVENT_NOTIF_ID = 9102

        // Whether the foreground service is currently up. Read by the Flutter
        // side (via MainActivity) to show the correct on/off state.
        @Volatile
        var isRunning = false
            private set
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    // When true, the service stays alive between calls (started via
    // ACTION_START_PERSISTENT). When false, it tears itself down ~25s after a
    // call ends (the original per-call behaviour).
    @Volatile
    private var persistent = false
    private var lastNumber: String? = null
    // "incoming" if we ever saw RINGING for this call; "outgoing" otherwise.
    // OFFHOOK alone after IDLE → outgoing dial. RINGING then OFFHOOK → incoming pickup.
    private var lastDirection: String = "outgoing"

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForegroundCompat(buildIdleNotification("Listening for calls"))
        isRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_IDLE
        val incoming = intent?.getStringExtra(EXTRA_NUMBER)
        Log.d(TAG, "onStartCommand action=$action number=$incoming persistent=$persistent")

        when (action) {
            ACTION_START_PERSISTENT -> {
                persistent = true
                // Foreground was already established in onCreate; just refresh
                // the ongoing notification so the user sees the correct state.
                updateIdleNotification("Listening for calls")
            }
            ACTION_STOP_PERSISTENT -> {
                persistent = false
                stopForegroundAndSelf()
            }
            ACTION_RINGING -> handleRinging(incoming)
            ACTION_OFFHOOK -> handleOffhook()
            ACTION_IDLE -> handleIdle()
        }
        // Sticky so OS restarts us if killed mid-call / in persistent mode.
        return START_STICKY
    }

    private fun stopForegroundAndSelf() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (_: Exception) {}
        stopSelf()
    }

    private fun handleRinging(numberFromIntent: String?) {
        lastDirection = "incoming"
        if (!numberFromIntent.isNullOrBlank()) {
            onNumberResolved(numberFromIntent, "incoming")
        } else {
            mainHandler.postDelayed({ resolveFromCallLog("incoming") }, 600)
        }
    }

    private fun handleOffhook() {
        // OFFHOOK fires for both outgoing dial and incoming pickup. CallLog
        // is usually written by now for outgoing.
        if (lastNumber == null) {
            // If we already marked incoming via RINGING, preserve that.
            mainHandler.postDelayed({ resolveFromCallLog(lastDirection) }, 600)
        }
    }

    // Captured contact name from CallLog / filename — used as a fallback
    // identifier + for ContactsContract lookup when the number is null.
    @Volatile
    private var lastContactName: String? = null
    private val idleStartedAt: Long
        get() = System.currentTimeMillis()

    private fun handleIdle() {
        val initialNumber = lastNumber
        val idleAt = System.currentTimeMillis()
        // Emit the end event immediately so the UI knows the call wrapped.
        CallDetectBridge.emitCallEnded(initialNumber)
        updateIdleNotification("Last call: ${initialNumber ?: "…"} — resolving…")

        // Multi-stage number resolution — CallLog write on Android 15 / Realme
        // takes 500ms-4s, and PHONE_STATE strips the outgoing number entirely
        // on Android 10+. We fan out lookups so at least one succeeds:
        //   1s / 2s / 4s / 6s / 8s   → poll CallLog by DATE ≥ idle-start (only
        //                              rows from THIS call, not any previous)
        //   post-poll                → resolve contact name from CallLog
        //                              CACHED_NAME, then look up the phone
        //                              number via ContactsContract if
        //                              CallLog.NUMBER is still blank/null
        //   10s                      → emit CALL_LOG event with best-known
        //                              (number, contactName) and scan for MP3
        for (delay in listOf(1_000L, 2_000L, 4_000L, 6_000L, 8_000L)) {
            mainHandler.postDelayed({ refreshFromCallLogPostIdle(idleAt) }, delay)
        }
        mainHandler.postDelayed({
            // If still no number, try ContactsContract with the contact name
            // (Realme OEM writes filename like "Home-YYMMDDHHMM..." — the
            // parser gives us "Home" as contactNameHint).
            if (lastNumber.isNullOrBlank() && !lastContactName.isNullOrBlank()) {
                val fromContacts = resolveNumberFromContacts(lastContactName!!)
                if (!fromContacts.isNullOrBlank()) {
                    lastNumber = fromContacts
                    Log.d(TAG, "resolved via ContactsContract: $lastContactName → $fromContacts")
                }
            }
            val numberAtCallEnd = lastNumber ?: initialNumber
            val (status, dur) = readLastCallStatusAndDuration()
            // Fire CALL_LOG event even if number is null — Flutter side will
            // fall back to contactName so the CRM Call Log row still exists
            // (with 'to' = "Home" or whoever) rather than being lost entirely.
            CallDetectBridge.emitCallLogReady(
                number = numberAtCallEnd,
                direction = lastDirection,
                status = status,
                durationSec = dur,
                contactName = lastContactName,
            )
            scanAndDispatch(numberAtCallEnd, attempt = 0)
        }, 20_000)
        // In persistent mode we stay alive between calls (so the OEM can't put
        // the app back into the stopped state and drop the next broadcast); we
        // just reset the ongoing notification back to idle. In per-call mode we
        // tear down ~60s after the call. This must outlast the recording-scan
        // retry schedule (first scan at 20s, then up to 4 retries 5s apart ≈
        // 40s) so slow phones that flush the recording file late aren't cut off.
        if (persistent) {
            mainHandler.postDelayed({
                updateIdleNotification("Listening for calls")
            }, 60_000)
        } else {
            mainHandler.postDelayed({ stopSelf() }, 60_000)
        }
        // Reset direction + contact so the next call starts fresh; leave
        // lastNumber alone so scanAndDispatch can still read it.
        lastNumber = null
    }

    /**
     * Look up a saved contact's phone number by their display name. Uses
     * ContactsContract — requires READ_CONTACTS. Returns the first phone
     * associated with the name, or null if not found / no permission.
     * This is the "hail Mary" path for OEM recorders that bake only the
     * contact name into the filename (Realme, Oppo).
     */
    private fun resolveNumberFromContacts(displayName: String): String? {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS)
            != PackageManager.PERMISSION_GRANTED) return null
        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(
                android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER),
                "${android.provider.ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} = ?",
                arrayOf(displayName),
                null,
            )
            if (cursor != null && cursor.moveToFirst()) {
                return cursor.getString(0)?.takeIf { it.isNotBlank() }
            }
        } catch (e: Exception) {
            Log.e(TAG, "ContactsContract lookup failed: ${e.message}", e)
        } finally {
            cursor?.close()
        }
        return null
    }

    /**
     * Read the CallLog row for the just-ended call. Called five times on
     * an escalating delay because OEMs flush at different speeds — Realme
     * Android 15 is particularly slow, sometimes 3-4 seconds after IDLE.
     *
     * Guards:
     *   * Only accepts rows with `date >= idleAt - 60s` so we can't pick
     *     up a stale previous-call row (the LIMIT 1 approach was fragile).
     *   * Also captures CACHED_NAME (contact name) so we can fall back to
     *     ContactsContract if NUMBER is somehow blank.
     */
    private fun refreshFromCallLogPostIdle(idleAt: Long) {
        // Already resolved — nothing to do.
        if (!lastNumber.isNullOrBlank()) return
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG)
            != PackageManager.PERMISSION_GRANTED) return
        val minDate = idleAt - 60_000L
        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(
                    CallLog.Calls.NUMBER,
                    CallLog.Calls.CACHED_NAME,
                    CallLog.Calls.TYPE,
                    CallLog.Calls.DATE,
                    CallLog.Calls.DURATION,
                ),
                "${CallLog.Calls.DATE} >= ?",
                arrayOf(minDate.toString()),
                // NOTE: no "LIMIT 1" here — Android 11+ (API 30) rejects LIMIT
                // in the sort-order arg ("Invalid token LIMIT"). We sort DATE
                // DESC and read only moveToFirst(), which is the latest row.
                "${CallLog.Calls.DATE} DESC",
            )
            if (cursor != null && cursor.moveToFirst()) {
                val num = cursor.getString(cursor.getColumnIndexOrThrow(CallLog.Calls.NUMBER))
                val cachedName = cursor.getString(cursor.getColumnIndexOrThrow(CallLog.Calls.CACHED_NAME))
                val type = cursor.getInt(cursor.getColumnIndexOrThrow(CallLog.Calls.TYPE))
                if (!cachedName.isNullOrBlank()) {
                    lastContactName = cachedName
                }
                if (!num.isNullOrBlank()) {
                    lastNumber = num
                    val dir = when (type) {
                        CallLog.Calls.INCOMING_TYPE -> "incoming"
                        CallLog.Calls.OUTGOING_TYPE -> "outgoing"
                        CallLog.Calls.MISSED_TYPE -> "incoming"
                        CallLog.Calls.REJECTED_TYPE -> "incoming"
                        else -> lastDirection
                    }
                    lastDirection = dir
                    Log.d(TAG, "post-idle CallLog → num=$num cachedName=$cachedName [$dir]")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "post-idle CallLog query failed: ${e.message}", e)
        } finally {
            cursor?.close()
        }
    }

    /**
     * Read the last call's terminal status (Completed / No answer / Busy /
     * Rejected) + duration from CallLog. Used to log a CRM Call Log even
     * when no recording is found — so the user has a record of every call
     * attempt, connected or not.
     */
    private fun readLastCallStatusAndDuration(): Pair<String, Int> {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG)
            != PackageManager.PERMISSION_GRANTED) return "Completed" to 0
        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(CallLog.Calls.TYPE, CallLog.Calls.DURATION),
                null, null,
                // NOTE: no "LIMIT 1" here — Android 11+ (API 30) rejects LIMIT
                // in the sort-order arg ("Invalid token LIMIT"). We sort DATE
                // DESC and read only moveToFirst(), which is the latest row.
                "${CallLog.Calls.DATE} DESC",
            )
            if (cursor != null && cursor.moveToFirst()) {
                val type = cursor.getInt(cursor.getColumnIndexOrThrow(CallLog.Calls.TYPE))
                val dur = cursor.getLong(cursor.getColumnIndexOrThrow(CallLog.Calls.DURATION)).toInt()
                val status = when {
                    type == CallLog.Calls.MISSED_TYPE -> "No Answer"
                    type == CallLog.Calls.REJECTED_TYPE -> "Rejected"
                    type == CallLog.Calls.OUTGOING_TYPE && dur == 0 -> "No Answer"
                    type == CallLog.Calls.INCOMING_TYPE && dur == 0 -> "No Answer"
                    dur > 0 -> "Completed"
                    else -> "Completed"
                }
                return status to dur
            }
        } catch (e: Exception) {
            Log.e(TAG, "last-call status query failed: ${e.message}", e)
        } finally {
            cursor?.close()
        }
        return "Completed" to 0
    }

    private fun scanAndDispatch(numberAtCallEnd: String?, attempt: Int) {
        // Slow phones (and some OEM recorders) flush the recording file well
        // after the call ends, so we retry several times with a widening
        // look-back window instead of giving up after one retry.
        val maxAttempts = 4
        val windowSec = 60 + attempt * 60 // 60s, 120s, 180s, 240s
        val hit = RecordingScanner.findLatest(
            windowSec = windowSec,
            hintNumber = numberAtCallEnd,
        )
        if (hit == null) {
            if (attempt < maxAttempts) {
                // Try again after a longer write delay.
                mainHandler.postDelayed({ scanAndDispatch(numberAtCallEnd, attempt + 1) }, 5_000)
            } else {
                Log.d("TcbCallSvc", "No recording found after ${maxAttempts + 1} tries — phone may not be configured for built-in recording")
                updateIdleNotification("Last call: ${numberAtCallEnd ?: "—"} — no recording captured")
            }
            return
        }
        Log.d("TcbCallSvc", "Recording found: ${hit.path}  parsedContact=${hit.parsedContact}  parsedNumber=${hit.parsedNumber}")
        updateIdleNotification("Last call recording found — uploading…")
        // Fallback chain for number:
        //   1. numberAtCallEnd (from CallLog re-query in handleIdle)
        //   2. hit.parsedNumber (filename bakes number on some OEMs)
        //   3. ContactsContract lookup on hit.parsedContact (Realme/Oppo case)
        var effectiveNumber = numberAtCallEnd.takeUnless { it.isNullOrBlank() }
            ?: hit.parsedNumber?.takeUnless { it.isBlank() }
        val contactHint = hit.parsedContact ?: lastContactName
        if (effectiveNumber.isNullOrBlank() && !contactHint.isNullOrBlank()) {
            effectiveNumber = resolveNumberFromContacts(contactHint)
            if (!effectiveNumber.isNullOrBlank()) {
                Log.d("TcbCallSvc", "recording number resolved from contacts: $contactHint → $effectiveNumber")
            }
        }
        CallDetectBridge.emitRecordingFound(
            number = effectiveNumber,
            path = hit.path,
            sizeBytes = hit.sizeBytes,
            folder = hit.folder,
            mtimeMs = hit.mtimeMs,
            direction = lastDirection,
            contactNameHint = contactHint,
        )
        // Reset direction for the next call.
        lastDirection = "outgoing"
    }

    private fun resolveFromCallLog(direction: String) {
        // Need READ_CALL_LOG. If absent, nothing to do.
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "READ_CALL_LOG denied — cannot resolve number")
            return
        }
        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.TYPE, CallLog.Calls.DATE),
                null,
                null,
                // NOTE: no "LIMIT 1" here — Android 11+ (API 30) rejects LIMIT
                // in the sort-order arg ("Invalid token LIMIT"). We sort DATE
                // DESC and read only moveToFirst(), which is the latest row.
                "${CallLog.Calls.DATE} DESC",
            )
            if (cursor != null && cursor.moveToFirst()) {
                val numIdx = cursor.getColumnIndexOrThrow(CallLog.Calls.NUMBER)
                val num = cursor.getString(numIdx)
                if (!num.isNullOrBlank()) {
                    onNumberResolved(num, direction)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "CallLog query failed: ${e.message}", e)
        } finally {
            cursor?.close()
        }
    }

    private fun onNumberResolved(number: String, direction: String) {
        lastNumber = number
        Log.d(TAG, "Resolved number: $number ($direction)")
        // Tell Flutter so it can hit lookup_by_phone + render caller card.
        CallDetectBridge.emitCallDetected(number, direction)
        // Post a separate event notification (visible even if app is closed).
        showCallerNotification(number, direction)
    }

    // ---------- Notifications ----------

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Call Detection",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Background service that watches for calls and captures recordings."
            setShowBadge(false)
        }
        nm.createNotificationChannel(channel)
    }

    private fun buildIdleNotification(text: String): Notification {
        val openApp = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("TCB Portal — Call Detection")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_notify_call_mute)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openApp)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateIdleNotification(text: String) {
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(FG_NOTIF_ID, buildIdleNotification(text))
    }

    private fun showCallerNotification(number: String, direction: String) {
        val openApp = PendingIntent.getActivity(
            this, 1,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("tcb.call.deeplink", "lookup:$number")
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val title = if (direction == "incoming") "Incoming call: $number" else "Outgoing call: $number"
        val body = "Tap to open in TCB Portal and view CRM context."
        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.stat_notify_call_mute)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setAutoCancel(true)
            .setContentIntent(openApp)
            .build()
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(EVENT_NOTIF_ID, notif)
    }

    private fun startForegroundCompat(notif: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+ requires explicit foregroundServiceType.
            // FOREGROUND_SERVICE_TYPE_SPECIAL_USE is acceptable for our case
            // (no narrower type fits — we're not a dialer or media app).
            startForeground(
                FG_NOTIF_ID, notif,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(FG_NOTIF_ID, notif)
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "Service destroyed")
        isRunning = false
        super.onDestroy()
    }
}
