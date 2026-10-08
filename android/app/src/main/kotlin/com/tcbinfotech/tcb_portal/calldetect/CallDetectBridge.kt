package com.tcbinfotech.tcb_portal.calldetect

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

/**
 * Static singleton that lets the [CallDetectionService] (background) push
 * events up to the Flutter engine via a [MethodChannel].
 *
 * Wired by [MainActivity.configureFlutterEngine] on app start. When the app
 * is killed, [channel] is null and events fall on the floor — that's OK
 * because the notification posted by the service still reaches the user.
 *
 * Channel name: tcb_portal/call_detect
 *
 * Flutter-side methods invoked:
 *   onCallDetected   { "number": String, "direction": "incoming"|"outgoing" }
 *   onCallEnded      { "number": String? }
 *
 * Flutter → native (TODO in D.2.3+):
 *   isServiceRunning, dismissOverlay, openRecording(<path>)
 */
object CallDetectBridge {

    @Volatile
    private var channel: MethodChannel? = null
    private val main = Handler(Looper.getMainLooper())

    fun attach(c: MethodChannel) {
        channel = c
    }

    fun detach() {
        channel = null
    }

    fun emitCallDetected(number: String, direction: String) {
        post("onCallDetected", mapOf("number" to number, "direction" to direction))
    }

    fun emitCallEnded(number: String?) {
        post("onCallEnded", mapOf("number" to (number ?: "")))
    }

    /**
     * Fired after a call ends and the CallLog has been queried for the
     * authoritative number + status. Flutter persists a CRM Call Log row
     * even when no recording is found (call didn't connect, OEM doesn't
     * record, etc.) — so the user has a record of every dial attempt.
     *
     * status ∈ {"Completed", "No Answer", "Busy", "Rejected"}
     */
    fun emitCallLogReady(
        number: String?,
        direction: String,
        status: String,
        durationSec: Int,
        contactName: String? = null,
    ) {
        post(
            "onCallLogReady",
            mapOf(
                "number" to (number ?: ""),
                "contact_name" to (contactName ?: ""),
                "direction" to direction,
                "status" to status,
                "duration_sec" to durationSec,
            ),
        )
    }

    fun emitRecordingFound(
        number: String?,
        path: String,
        sizeBytes: Long,
        folder: String,
        mtimeMs: Long,
        direction: String = "outgoing",
        contactNameHint: String? = null,
    ) {
        post(
            "onRecordingFound",
            mapOf(
                "number" to (number ?: ""),
                "path" to path,
                "size_bytes" to sizeBytes,
                "folder" to folder,
                "mtime_ms" to mtimeMs,
                "direction" to direction,
                "contact_name_hint" to (contactNameHint ?: ""),
            ),
        )
    }

    private fun post(method: String, args: Map<String, Any?>) {
        // MethodChannel calls MUST happen on the main thread.
        main.post { channel?.invokeMethod(method, args) }
    }
}
