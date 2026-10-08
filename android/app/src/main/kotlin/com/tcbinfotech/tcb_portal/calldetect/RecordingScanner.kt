package com.tcbinfotech.tcb_portal.calldetect

import android.os.Environment
import android.util.Log
import java.io.File

/**
 * Phase D.2.4 — Reads the OEM-recorded call MP3 from the device's
 * native recorder folder.
 *
 * Confirmed Realme 10 Pro+ Android 15 path:
 *   /storage/emulated/0/Music/Recordings/Call Recordings/
 *   Filename: <ContactNameOrPlusNumber>-<YYMMDDHHmm>.mp3
 *   e.g. "Anuj Sharma-2606251545.mp3"  or  "+919876543210-2510171715.mp3"
 *
 * Other OEMs (verified via Runo / Kylas / TeleCRM docs):
 *   * Samsung One UI: /Recordings/Call/    or  /Sounds/Call/
 *   * Xiaomi/MIUI:    /MIUI/sound_recorder/call_rec/
 *                     or /Sounds/CallRecorder/
 *   * Oppo:           /Music/Recordings/Call Recordings/    (same as Realme)
 *   * Vivo:           /Record/Call/  or  /Recordings/Call/ or Recordings/Record/Call
 *   * OnePlus:        /Recordings/   (varies by OxygenOS version)
 *
 * Strategy:
 *   1. Scan ALL known absolute paths
 *   2. Pick the most-recently-modified audio file whose mtime is within
 *      `windowSec` of the moment the call ended
 *   3. If we have the call's phone number, prefer files whose filename
 *      contains it (Realme/Oppo bake the number into the name)
 */
object RecordingScanner {

    private const val TAG = "TcbRecordingScanner"

    // Folder paths to scan, in priority order. Most specific OEM-confirmed
    // paths first. All resolved against Environment.getExternalStorageDirectory().
    private val KNOWN_FOLDERS = listOf(
        // Realme / Oppo ColorOS (CONFIRMED on RMX3686 / Android 15)
        "Music/Recordings/Call Recordings",
        "Recordings/Record/Call",
        "Music/Recordings/Call recordings",
        "Recordings/Call Recordings",
        "Recordings/CallRecordings",
        "Music/Recordings/Call",
        // Samsung One UI
        "Recordings/Call",
        "Sounds/Call",
        // MIUI / HyperOS
        "MIUI/sound_recorder/call_rec",
        "Sounds/CallRecorder",
        // Vivo / iQOO (FuntouchOS / OriginOS)
        "Record/Call",
        "Record/PhoneRecord",
        "PhoneRecord",
        "Recordings/Call Recordings",
        "Recordings/Record/Call",
        "vivo/Record/Call",
        "录音/通话录音",
        // OnePlus / others
        "Recordings",
        "Call recordings",
        "CallRecordings",
    )

    // Recording "root" folders whose immediate subfolders we also scan, so an
    // OEM whose exact leaf name differs from the list above (common on Vivo /
    // OnePlus builds) is still caught without hardcoding every variant.
    private val RECORDING_ROOTS = listOf(
        "Recordings",
        "Record",
        "Music/Recordings",
        "Sounds",
        "PhoneRecord",
        "录音",
    )

    private val AUDIO_EXTS = setOf("mp3", "m4a", "amr", "wav", "aac", "ogg", "opus")

    data class Hit(
        val path: String,
        val mtimeMs: Long,
        val sizeBytes: Long,
        val folder: String,
        val matchedByNumber: Boolean,
        // Realme/Oppo bake the contact name or +91… number into the filename
        // ("Anuj Sharma-2606251545.mp3" or "+919876543210-2510171715.mp3").
        // We parse it as a fallback when the OS strips EXTRA_INCOMING_NUMBER
        // and CallLog hasn't been written yet.
        val parsedContact: String?,
        val parsedNumber: String?,
    )

    // Trailing timestamp patterns OEMs bake into recording filenames, tried in
    // order. The contact/number is whatever comes BEFORE the match.
    //   * Realme / Oppo : "Anuj Sharma-2606251545"      (dash + 10-12 digits)
    //   * Vivo / iQOO   : "Nonu 2026-09-24 12-31-31"    (space + full date-time)
    //   * generic       : "Name_20260924123131"         (sep + long digit run)
    private val TS_PATTERNS = listOf(
        Regex("-(\\d{10,12})$"),
        Regex("[ _](\\d{4}-\\d{2}-\\d{2}[ _]\\d{2}[-:.]\\d{2}[-:.]\\d{2})$"),
        Regex("[ _](\\d{4}\\d{2}\\d{2}[ _]?\\d{2}\\d{2}\\d{2})$"),
        Regex("[ _](\\d{8,14})$"),
    )

    /**
     * Pull contact-name and/or phone-number from the OEM-baked filename.
     * Handles the dash form ("Anuj Sharma-2606251545") AND the space form
     * Vivo/iQOO use ("Nonu 2026-09-24 12-31-31"), where the older dash-only
     * parser left the whole name+timestamp as a bogus "contact".
     */
    private fun parseFilename(nameNoExt: String): Pair<String?, String?> {
        var prefix = nameNoExt
        for (re in TS_PATTERNS) {
            val m = re.find(prefix)
            if (m != null) {
                prefix = prefix.substring(0, m.range.first)
                break
            }
        }
        // Strip common OEM labels + leftover separators.
        prefix = prefix
            .replace(Regex("(?i)^(call ?recording|recording|record|通话录音)"), "")
            .trim()
            .trim('-', '_', ' ')
            .trim()
        if (prefix.isEmpty()) return Pair(null, null)
        return if (prefix.startsWith("+") || prefix.all { it.isDigit() }) {
            // It's a phone number
            Pair(null, prefix)
        } else {
            // It's a contact name
            Pair(prefix, null)
        }
    }

    /**
     * Find the latest recording file.
     *
     * @param windowSec Look back this many seconds from now.
     * @param hintNumber If non-null, prefer files whose name contains the
     *                   last 7-10 digits of this number (Realme/Oppo embed
     *                   the number in the filename).
     */
    fun findLatest(windowSec: Int = 90, hintNumber: String? = null): Hit? {
        val root = Environment.getExternalStorageDirectory()
        if (root == null || !root.exists()) {
            Log.w(TAG, "External storage not accessible — audio/storage permission granted?")
            return null
        }
        val cutoffMs = System.currentTimeMillis() - windowSec * 1000L
        val numberTail = hintNumber
            ?.replace(Regex("[^0-9]"), "")
            ?.takeLast(10)
            ?.takeIf { it.length >= 7 }

        // Expand the fixed folder list with the immediate subfolders of each
        // recording root, so OEM-specific leaf names we did not hardcode are
        // still scanned. De-duped, order-preserving.
        val foldersToScan = LinkedHashSet<String>(KNOWN_FOLDERS)
        for (rootRel in RECORDING_ROOTS) {
            val rootDir = File(root, rootRel)
            if (!rootDir.exists() || !rootDir.isDirectory) continue
            try {
                rootDir.listFiles()?.forEach { sub ->
                    if (sub.isDirectory) foldersToScan.add("$rootRel/${sub.name}")
                }
            } catch (e: Exception) {
                Log.w(TAG, "Root scan failed for $rootRel: ${e.message}")
            }
        }

        var byNumberHit: Hit? = null
        var anyHit: Hit? = null
        for (rel in foldersToScan) {
            val dir = File(root, rel)
            if (!dir.exists() || !dir.isDirectory) continue
            try {
                val files = dir.listFiles() ?: continue
                for (f in files) {
                    if (!f.isFile) continue
                    val ext = f.extension.lowercase()
                    if (ext !in AUDIO_EXTS) continue
                    if (f.lastModified() < cutoffMs) continue
                    val (parsedContact, parsedNumber) = parseFilename(f.nameWithoutExtension)
                    val hit = Hit(
                        path = f.absolutePath,
                        mtimeMs = f.lastModified(),
                        sizeBytes = f.length(),
                        folder = rel,
                        matchedByNumber = numberTail != null &&
                            f.nameWithoutExtension.replace(Regex("[^0-9]"), "")
                                .contains(numberTail),
                        parsedContact = parsedContact,
                        parsedNumber = parsedNumber,
                    )
                    if (hit.matchedByNumber &&
                        (byNumberHit == null || hit.mtimeMs > byNumberHit.mtimeMs)) {
                        byNumberHit = hit
                    }
                    if (anyHit == null || hit.mtimeMs > anyHit.mtimeMs) {
                        anyHit = hit
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Scan failed for $rel: ${e.message}")
            }
        }

        val best = byNumberHit ?: anyHit
        if (best != null) {
            Log.d(
                TAG,
                "Found recording: ${best.path} (${best.sizeBytes}B, " +
                    "matchedByNumber=${best.matchedByNumber}, folder=${best.folder})"
            )
        } else {
            Log.d(TAG, "No recording in any known folder within last ${windowSec}s " +
                "(hintNumber=${hintNumber ?: "—"})")
        }
        return best
    }
}
