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
import kotlin.concurrent.thread

/**
 * Shizuku UserService — runs as shell UID so privileged telephony sources may work.
 * Writes a 16-bit PCM WAV to the ParcelFileDescriptor provided by the app.
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
    private var audioRecord: AudioRecord? = null
    private var writeThread: Thread? = null
    private var outputStream: FileOutputStream? = null
    private var activeSource: String = "NONE"
    private var dataBytes: Long = 0L
    private var sampleRate: Int = 44100
    private var channelCount: Int = 1

    override fun ping(): String = "pong shell=${android.os.Process.myUid()}"

    override fun startRecording(pfd: ParcelFileDescriptor?): String {
        if (pfd == null) return "ERR:null_pfd"
        if (!recording.compareAndSet(false, true)) return "ERR:already_recording"

        val sources = listOf(
            "VOICE_CALL" to MediaRecorder.AudioSource.VOICE_CALL,
            "VOICE_DOWNLINK" to MediaRecorder.AudioSource.VOICE_DOWNLINK,
            "VOICE_UPLINK" to MediaRecorder.AudioSource.VOICE_UPLINK,
            "VOICE_COMMUNICATION" to MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            "MIC" to MediaRecorder.AudioSource.MIC,
        )

        var lastError = "no_source"
        for ((name, source) in sources) {
            var record: AudioRecord? = null
            try {
                val rate = 44100
                val channelConfig = AudioFormat.CHANNEL_IN_MONO
                val encoding = AudioFormat.ENCODING_PCM_16BIT
                val minBuf = AudioRecord.getMinBufferSize(rate, channelConfig, encoding)
                if (minBuf <= 0) {
                    lastError = "$name:bad_buffer"
                    continue
                }
                val bufSize = minBuf * 2
                record = AudioRecord(source, rate, channelConfig, encoding, bufSize)
                if (record.state != AudioRecord.STATE_INITIALIZED) {
                    lastError = "$name:not_initialized"
                    record.release()
                    continue
                }

                val fos = FileOutputStream(pfd.fileDescriptor)
                writeWavHeader(fos, rate, 1, 0)
                dataBytes = 0L
                sampleRate = rate
                channelCount = 1
                activeSource = name
                audioRecord = record
                outputStream = fos

                record.startRecording()
                writeThread = thread(name = "shizuku-wav-writer", isDaemon = true) {
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
                            Log.w(TAG, "AudioRecord read error=$read")
                            break
                        }
                    }
                }

                Log.i(TAG, "Recording started source=$name")
                return "OK:$name"
            } catch (e: Exception) {
                lastError = "$name:${e.message}"
                Log.w(TAG, "source $name failed", e)
                try {
                    record?.release()
                } catch (_: Exception) {
                }
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

    override fun stopRecording(): String {
        if (!recording.getAndSet(false)) {
            return "ERR:not_recording"
        }
        return try {
            try {
                audioRecord?.stop()
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
            audioRecord?.release()
        } catch (_: Exception) {
        }
        audioRecord = null
        try {
            outputStream?.close()
        } catch (_: Exception) {
        }
        outputStream = null
        writeThread = null
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

    companion object {
        private const val TAG = "ShizukuRecorderSvc"
    }
}
