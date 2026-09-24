package com.callvault.prototype.shizuku

import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.util.Log
import com.callvault.prototype.IShizukuRecorder
import com.callvault.prototype.recorder.CallRecorder
import rikka.shizuku.Shizuku
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Client-side Shizuku binder for the shell UserService recorder.
 */
class ShizukuRecorderClient(private val context: Context) {
    private var service: IShizukuRecorder? = null
    private var bound = false
    private var outputFile: File? = null
    private var pfd: ParcelFileDescriptor? = null
    private var activeSource: String? = null
    private var startedAtMs: Long = 0L

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            service = IShizukuRecorder.Stub.asInterface(binder)
            bound = true
            Log.i(TAG, "UserService connected")
            connectLatch?.countDown()
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            service = null
            bound = false
            Log.w(TAG, "UserService disconnected")
        }
    }

    @Volatile
    private var connectLatch: CountDownLatch? = null

    fun status(): Map<String, Any?> {
        val binderAlive = try {
            Shizuku.pingBinder()
        } catch (_: Exception) {
            false
        }
        val permission = try {
            if (binderAlive) {
                Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
            } else {
                false
            }
        } catch (_: Exception) {
            false
        }
        return mapOf(
            "installed" to isShizukuInstalled(),
            "running" to binderAlive,
            "permission" to permission,
            "bound" to bound,
            "recording" to (service?.isRecording == true),
            "uidHint" to try {
                if (bound) service?.ping() else null
            } catch (_: Exception) {
                null
            },
        )
    }

    fun requestPermission(requestCode: Int = REQ_CODE): Boolean {
        return try {
            if (!Shizuku.pingBinder()) return false
            if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) return true
            Shizuku.requestPermission(requestCode)
            true
        } catch (e: Exception) {
            Log.e(TAG, "requestPermission failed", e)
            false
        }
    }

    fun ensureBound(timeoutMs: Long = 8_000): Boolean {
        if (service != null && bound) return true
        if (!Shizuku.pingBinder()) return false
        if (Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) return false

        connectLatch = CountDownLatch(1)
        val args = Shizuku.UserServiceArgs(
            ComponentName(context.packageName, ShizukuRecorderService::class.java.name),
        )
            .daemon(false)
            .processNameSuffix("recorder")
            .debuggable(true)
            .version(USER_SERVICE_VERSION)
            .tag("callvault-recorder")

        return try {
            Shizuku.bindUserService(args, connection)
            val ok = connectLatch?.await(timeoutMs, TimeUnit.MILLISECONDS) == true && service != null
            if (!ok) {
                Log.e(TAG, "bindUserService timed out")
            }
            ok
        } catch (e: Exception) {
            Log.e(TAG, "bindUserService failed", e)
            false
        }
    }

    fun start(): CallRecorder.StartResult {
        if (!ensureBound()) {
            return CallRecorder.StartResult(
                false,
                null,
                null,
                "Shizuku not ready (install/start Shizuku, grant permission, Wireless Debugging)",
            )
        }
        val svc = service
            ?: return CallRecorder.StartResult(false, null, null, "UserService not bound")

        val dir = File(context.getExternalFilesDir(null), "Recordings")
        if (!dir.exists() && !dir.mkdirs()) {
            return CallRecorder.StartResult(false, null, null, "Could not create Recordings directory")
        }
        val stamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        val file = File(dir, "shizuku_$stamp.wav")
        if (file.exists()) file.delete()
        file.createNewFile()

        val descriptor = try {
            ParcelFileDescriptor.open(
                file,
                ParcelFileDescriptor.MODE_READ_WRITE or ParcelFileDescriptor.MODE_TRUNCATE,
            )
        } catch (e: Exception) {
            return CallRecorder.StartResult(false, null, null, "PFD open failed: ${e.message}")
        }

        return try {
            val reply = svc.startRecording(descriptor)
            if (reply.startsWith("OK:")) {
                outputFile = file
                pfd = descriptor
                activeSource = "SHIZUKU_${reply.removePrefix("OK:")}"
                startedAtMs = System.currentTimeMillis()
                CallRecorder.StartResult(true, file.absolutePath, activeSource, null)
            } else {
                descriptor.close()
                file.delete()
                CallRecorder.StartResult(
                    false,
                    null,
                    null,
                    reply.removePrefix("ERR:").ifBlank { reply },
                )
            }
        } catch (e: Exception) {
            try {
                descriptor.close()
            } catch (_: Exception) {
            }
            file.delete()
            CallRecorder.StartResult(false, null, null, e.message)
        }
    }

    fun stop(): CallRecorder.StopResult {
        val svc = service
        val file = outputFile
        val source = activeSource
        val duration = (System.currentTimeMillis() - startedAtMs).coerceAtLeast(0L)

        if (svc == null) {
            cleanupLocal()
            return CallRecorder.StopResult(file?.absolutePath, duration, file?.length() ?: 0L, source, "Service gone")
        }

        return try {
            val reply = svc.stopRecording()
            cleanupLocal()
            val bytes = file?.length() ?: 0L
            if (reply.startsWith("OK:")) {
                CallRecorder.StopResult(file?.absolutePath, duration, bytes, source, null)
            } else {
                CallRecorder.StopResult(
                    file?.absolutePath,
                    duration,
                    bytes,
                    source,
                    reply.removePrefix("ERR:"),
                )
            }
        } catch (e: Exception) {
            cleanupLocal()
            CallRecorder.StopResult(file?.absolutePath, duration, file?.length() ?: 0L, source, e.message)
        }
    }

    fun unbind() {
        try {
            if (bound) {
                val args = Shizuku.UserServiceArgs(
                    ComponentName(context.packageName, ShizukuRecorderService::class.java.name),
                )
                    .daemon(false)
                    .processNameSuffix("recorder")
                    .debuggable(true)
                    .version(USER_SERVICE_VERSION)
                    .tag("callvault-recorder")
                Shizuku.unbindUserService(args, connection, true)
            }
        } catch (e: Exception) {
            Log.w(TAG, "unbind failed", e)
        }
        service = null
        bound = false
    }

    private fun cleanupLocal() {
        try {
            pfd?.close()
        } catch (_: Exception) {
        }
        pfd = null
        outputFile = null
        activeSource = null
        startedAtMs = 0L
    }

    private fun isShizukuInstalled(): Boolean {
        return try {
            context.packageManager.getPackageInfo("moe.shizuku.privileged.api", 0)
            true
        } catch (_: Exception) {
            try {
                context.packageManager.getPackageInfo("moe.shizuku.manager", 0)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    companion object {
        private const val TAG = "ShizukuRecorderClient"
        const val REQ_CODE = 1501
        private const val USER_SERVICE_VERSION = 3
    }
}
