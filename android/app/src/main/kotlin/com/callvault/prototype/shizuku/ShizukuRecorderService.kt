package com.callvault.prototype.shizuku

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.ParcelFileDescriptor
import android.util.Log
import com.callvault.prototype.IShizukuRecorder
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max
import kotlin.concurrent.thread

/**
 * Shizuku UserService — shell UID capture without VOICE_CALL / VOICE_COMMUNICATION.
 *
 * Those mixed sources often steal the telephony route and mute the live call.
 * Prefer mixing VOICE_DOWNLINK + VOICE_UPLINK (or downlink/mic alone).
 */
class ShizukuRecorderService : IShizukuRecorder.Stub {
    constructor() {
        Log.i(TAG, "ShizukuRecorderService created")
    }

    @Suppress("UNUSED_PARAMETER")
    constructor(context: Context) {
        Log.i(TAG, "ShizukuRecorderService created with context")
    }

    private val recording = AtomicBoolean(false)
    private var primaryRecord: AudioRecord? = null
    private var secondaryRecord: AudioRecord? = null
    private var writeThread: Thread? = null
    private var outputStream: FileOutputStream? = null
    private var activeSource: String = "NONE"
    private var dataBytes: Long = 0L
    private var sampleRate: Int = SAMPLE_RATE
    private var channelCount: Int = 1

    override fun ping(): String = "pong shell=${android.os.Process.myUid()}"

    override fun startRecording(pfd: ParcelFileDescriptor?): String {
        if (pfd == null) return "ERR:null_pfd"
        if (!recording.compareAndSet(false, true)) return "ERR:already_recording"

        // Intentionally skip VOICE_CALL and VOICE_COMMUNICATION — they frequently mute live calls.
        val strategies = listOf(
            Strategy.Dual("DOWNLINK+UPLINK", MediaRecorder.AudioSource.VOICE_DOWNLINK, MediaRecorder.AudioSource.VOICE_UPLINK),
            Strategy.Dual("DOWNLINK+MIC", MediaRecorder.AudioSource.VOICE_DOWNLINK, MediaRecorder.AudioSource.MIC),
            Strategy.Single("VOICE_DOWNLINK", MediaRecorder.AudioSource.VOICE_DOWNLINK),
            Strategy.Single("VOICE_UPLINK", MediaRecorder.AudioSource.VOICE_UPLINK),
            Strategy.Single("MIC", MediaRecorder.AudioSource.MIC),
        )

        var lastError = "no_source"
        for (strategy in strategies) {
            try {
                val result = when (strategy) {
                    is Strategy.Dual -> startDual(pfd, strategy.label, strategy.a, strategy.b)
                    is Strategy.Single -> startSingle(pfd, strategy.label, strategy.source)
                }
                if (result != null) {
                    Log.i(TAG, "Recording started source=$result")
                    return "OK:$result"
                }
            } catch (e: Exception) {
                lastError = "${strategy.label}:${e.message}"
                Log.w(TAG, "strategy ${strategy.label} failed", e)
                releaseCapture()
            }
        }

        recording.set(false)
        try {
            pfd.close()
        } catch (_: Exception) {
        }
        return "ERR:$lastError"
    }

    private fun startSingle(pfd: ParcelFileDescriptor, label: String, source: Int): String? {
        val rate = SAMPLE_RATE
        val minBuf = AudioRecord.getMinBufferSize(rate, CHANNEL_CONFIG, ENCODING)
        if (minBuf <= 0) return null
        val bufSize = minBuf * 2
        val record = AudioRecord(source, rate, CHANNEL_CONFIG, ENCODING, bufSize)
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            return null
        }

        val fos = FileOutputStream(pfd.fileDescriptor)
        writeWavHeader(fos, rate, 1, 0)
        dataBytes = 0L
        sampleRate = rate
        channelCount = 1
        activeSource = label
        primaryRecord = record
        outputStream = fos

        record.startRecording()
        writeThread = thread(name = "shizuku-wav-single", isDaemon = true) {
            val buffer = ByteArray(bufSize)
            while (recording.get()) {
                val read = try {
                    record.read(buffer, 0, buffer.size)
                } catch (e: Exception) {
                    Log.e(TAG, "read failed", e)
                    break
                }
                if (read > 0) {
                    try {
                        fos.write(buffer, 0, read)
                        dataBytes += read
                    } catch (e: Exception) {
                        Log.e(TAG, "write failed", e)
                        break
                    }
                } else if (read < 0) {
                    break
                }
            }
        }
        return label
    }

    private fun startDual(pfd: ParcelFileDescriptor, label: String, sourceA: Int, sourceB: Int): String? {
        val rate = SAMPLE_RATE
        val minBuf = AudioRecord.getMinBufferSize(rate, CHANNEL_CONFIG, ENCODING)
        if (minBuf <= 0) return null
        val bufSize = minBuf * 2

        val a = AudioRecord(sourceA, rate, CHANNEL_CONFIG, ENCODING, bufSize)
        if (a.state != AudioRecord.STATE_INITIALIZED) {
            a.release()
            return null
        }
        val b = AudioRecord(sourceB, rate, CHANNEL_CONFIG, ENCODING, bufSize)
        if (b.state != AudioRecord.STATE_INITIALIZED) {
            a.release()
            b.release()
            return null
        }

        val fos = FileOutputStream(pfd.fileDescriptor)
        writeWavHeader(fos, rate, 1, 0)
        dataBytes = 0L
        sampleRate = rate
        channelCount = 1
        activeSource = label
        primaryRecord = a
        secondaryRecord = b
        outputStream = fos

        a.startRecording()
        b.startRecording()
        writeThread = thread(name = "shizuku-wav-dual", isDaemon = true) {
            val bufA = ByteArray(bufSize)
            val bufB = ByteArray(bufSize)
            val mixed = ByteArray(bufSize)
            while (recording.get()) {
                val readA = try {
                    a.read(bufA, 0, bufA.size)
                } catch (_: Exception) {
                    -1
                }
                val readB = try {
                    b.read(bufB, 0, bufB.size)
                } catch (_: Exception) {
                    -1
                }
                if (readA < 0 && readB < 0) break
                val n = max(0, max(readA, readB))
                if (n <= 0) continue
                // Mix 16-bit little-endian mono samples.
                var i = 0
                while (i + 1 < n) {
                    val sampleA = sampleAt(bufA, i, readA)
                    val sampleB = sampleAt(bufB, i, readB)
                    val sum = (sampleA + sampleB).coerceIn(
                        Short.MIN_VALUE.toInt(),
                        Short.MAX_VALUE.toInt(),
                    )
                    mixed[i] = (sum and 0xff).toByte()
                    mixed[i + 1] = ((sum shr 8) and 0xff).toByte()
                    i += 2
                }
                try {
                    fos.write(mixed, 0, n)
                    dataBytes += n
                } catch (e: Exception) {
                    Log.e(TAG, "write failed", e)
                    break
                }
            }
        }
        return label
    }

    override fun stopRecording(): String {
        if (!recording.getAndSet(false)) {
            return "ERR:not_recording"
        }
        return try {
            try {
                primaryRecord?.stop()
            } catch (_: Exception) {
            }
            try {
                secondaryRecord?.stop()
            } catch (_: Exception) {
            }
            writeThread?.join(3000)
            writeThread = null

            val fos = outputStream
            val bytes = dataBytes
            val source = activeSource
            if (fos != null) {
                try {
                    val channel = fos.channel
                    channel.position(0)
                    writeWavHeader(fos, sampleRate, channelCount, bytes)
                    fos.flush()
                } catch (e: Exception) {
                    Log.w(TAG, "header rewrite failed", e)
                }
            }
            releaseCapture()
            "OK:$source:$bytes"
        } catch (e: Exception) {
            releaseCapture()
            "ERR:${e.message}"
        }
    }

    override fun isRecording(): Boolean = recording.get()

    private fun releaseCapture() {
        try {
            primaryRecord?.release()
        } catch (_: Exception) {
        }
        primaryRecord = null
        try {
            secondaryRecord?.release()
        } catch (_: Exception) {
        }
        secondaryRecord = null
        try {
            outputStream?.close()
        } catch (_: Exception) {
        }
        outputStream = null
        writeThread = null
    }

    private fun sampleAt(buf: ByteArray, index: Int, validBytes: Int): Int {
        if (index + 1 >= validBytes) return 0
        val lo = buf[index].toInt() and 0xff
        val hi = buf[index + 1].toInt()
        return ((hi shl 8) or lo).toShort().toInt()
    }

    private fun writeWavHeader(
        out: FileOutputStream,
        sampleRate: Int,
        channels: Int,
        dataLen: Long,
    ) {
        val byteRate = sampleRate * channels * 2
        val totalDataLen = dataLen + 36
        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        header.put("RIFF".toByteArray(Charsets.US_ASCII))
        header.putInt(totalDataLen.toInt())
        header.put("WAVE".toByteArray(Charsets.US_ASCII))
        header.put("fmt ".toByteArray(Charsets.US_ASCII))
        header.putInt(16)
        header.putShort(1)
        header.putShort(channels.toShort())
        header.putInt(sampleRate)
        header.putInt(byteRate)
        header.putShort((channels * 2).toShort())
        header.putShort(16)
        header.put("data".toByteArray(Charsets.US_ASCII))
        header.putInt(dataLen.toInt())
        out.write(header.array())
    }

    private sealed class Strategy(val label: String) {
        class Single(label: String, val source: Int) : Strategy(label)
        class Dual(label: String, val a: Int, val b: Int) : Strategy(label)
    }

    companion object {
        private const val TAG = "ShizukuRecorderSvc"
        private const val SAMPLE_RATE = 44100
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
    }
}
