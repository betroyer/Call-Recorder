package com.callvault.prototype.recorder

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * MediaRecorder wrapper. Tries VOICE_COMMUNICATION first, then MIC.
 * Two-way cellular audio is device/OS dependent and not guaranteed.
 */
class CallRecorder(private val context: Context) {
    data class StartResult(
        val started: Boolean,
        val path: String?,
        val source: String?,
        val error: String?,
    )

    data class StopResult(
        val path: String?,
        val durationMs: Long,
        val bytes: Long,
        val source: String?,
        val error: String?,
    )

    private var mediaRecorder: MediaRecorder? = null
    private var outputFile: File? = null
    private var activeSource: String? = null
    private var startedAtMs: Long = 0L

    val isRecording: Boolean
        get() = mediaRecorder != null

    fun start(): StartResult {
        if (mediaRecorder != null) {
            return StartResult(false, outputFile?.absolutePath, activeSource, "Already recording")
        }

        val dir = File(context.getExternalFilesDir(null), "Recordings")
        if (!dir.exists() && !dir.mkdirs()) {
            return StartResult(false, null, null, "Could not create Recordings directory")
        }

        val stamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        val file = File(dir, "proto_$stamp.m4a")

        val sources = listOf(
            Pair("VOICE_COMMUNICATION", MediaRecorder.AudioSource.VOICE_COMMUNICATION),
            Pair("MIC", MediaRecorder.AudioSource.MIC),
        )

        var lastError: String? = null
        for ((name, source) in sources) {
            try {
                if (file.exists()) {
                    file.delete()
                }
                val recorder = createRecorder()
                recorder.setAudioSource(source)
                recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                recorder.setAudioEncodingBitRate(128_000)
                recorder.setAudioSamplingRate(44_100)
                recorder.setOutputFile(file.absolutePath)
                recorder.prepare()
                recorder.start()

                mediaRecorder = recorder
                outputFile = file
                activeSource = name
                startedAtMs = System.currentTimeMillis()
                Log.i(TAG, "Recording started with source=$name path=${file.absolutePath}")
                return StartResult(true, file.absolutePath, name, null)
            } catch (e: Exception) {
                lastError = "$name failed: ${e.message}"
                Log.w(TAG, lastError, e)
                releaseQuietly()
            }
        }

        return StartResult(false, null, null, lastError ?: "All audio sources failed")
    }

    fun stop(): StopResult {
        val recorder = mediaRecorder
            ?: return StopResult(null, 0, 0, activeSource, "Not recording")

        val path = outputFile?.absolutePath
        val source = activeSource
        val duration = (System.currentTimeMillis() - startedAtMs).coerceAtLeast(0L)

        return try {
            recorder.stop()
            releaseQuietly()
            val bytes = outputFile?.length() ?: 0L
            Log.i(TAG, "Recording stopped path=$path bytes=$bytes durationMs=$duration source=$source")
            StopResult(path, duration, bytes, source, null)
        } catch (e: Exception) {
            Log.e(TAG, "stop failed", e)
            releaseQuietly()
            val bytes = outputFile?.length() ?: 0L
            StopResult(path, duration, bytes, source, e.message)
        }
    }

    fun releaseQuietly() {
        try {
            mediaRecorder?.reset()
        } catch (_: Exception) {
        }
        try {
            mediaRecorder?.release()
        } catch (_: Exception) {
        }
        mediaRecorder = null
        activeSource = null
        startedAtMs = 0L
    }

    private fun createRecorder(): MediaRecorder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
    }

    companion object {
        private const val TAG = "CallRecorder"

        fun listRecordings(context: Context): List<Map<String, Any?>> {
            val dir = File(context.getExternalFilesDir(null), "Recordings")
            if (!dir.exists()) return emptyList()
            return dir.listFiles()
                ?.filter { it.isFile && it.extension.equals("m4a", ignoreCase = true) }
                ?.sortedByDescending { it.lastModified() }
                ?.map {
                    mapOf(
                        "path" to it.absolutePath,
                        "name" to it.name,
                        "bytes" to it.length(),
                        "modifiedMs" to it.lastModified(),
                    )
                }
                ?: emptyList()
        }

        fun lastRecordingPath(context: Context): String? {
            return listRecordings(context).firstOrNull()?.get("path") as String?
        }
    }
}
