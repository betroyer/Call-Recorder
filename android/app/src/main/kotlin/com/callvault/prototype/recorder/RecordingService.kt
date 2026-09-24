package com.callvault.prototype.recorder

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.callvault.prototype.MainActivity

/**
 * Foreground service that owns the MediaRecorder lifecycle during a call.
 */
class RecordingService : Service() {
    private val recorder by lazy { CallRecorder(applicationContext) }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                ensureForeground()
                val result = recorder.start()
                notifyListeners(result)
                if (!result.started) {
                    isRunning = false
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                } else {
                    isRunning = true
                }
            }
            ACTION_NOTIFY_ONLY -> {
                ensureForeground()
                isRunning = true
            }
            ACTION_STOP -> {
                if (recorder.isRecording) {
                    val result = recorder.stop()
                    listeners.forEach { it.onRecordingStopped(result) }
                }
                isRunning = false
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            else -> {
                ensureForeground()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        if (recorder.isRecording) {
            val result = recorder.stop()
            listeners.forEach { it.onRecordingStopped(result) }
        } else {
            recorder.releaseQuietly()
        }
        super.onDestroy()
    }

    private fun ensureForeground() {
        createChannel()
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun notifyListeners(result: CallRecorder.StartResult) {
        listeners.forEach { it.onRecordingStarted(result) }
    }

    private fun createChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Call recording",
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.description = "Shown while PYX Food Products is recording"
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val launch = Intent(this, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PYX Food Products — Recording")
            .setContentText("Recording active. Two-way audio is not guaranteed.")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    interface Listener {
        fun onRecordingStarted(result: CallRecorder.StartResult)
        fun onRecordingStopped(result: CallRecorder.StopResult)
    }

    companion object {
        private const val TAG = "RecordingService"
        private const val CHANNEL_ID = "callvault_recording"
        private const val NOTIFICATION_ID = 1001

        const val ACTION_START = "com.callvault.prototype.recorder.START"
        const val ACTION_NOTIFY_ONLY = "com.callvault.prototype.recorder.NOTIFY_ONLY"
        const val ACTION_STOP = "com.callvault.prototype.recorder.STOP"

        private val listeners = mutableSetOf<Listener>()

        @Volatile
        var isRunning: Boolean = false
            private set

        fun addListener(listener: Listener) {
            listeners.add(listener)
        }

        fun removeListener(listener: Listener) {
            listeners.remove(listener)
        }

        fun startNotifyOnly(context: Context) {
            val intent = Intent(context, RecordingService::class.java).apply {
                action = ACTION_NOTIFY_ONLY
            }
            try {
                context.startForegroundService(intent)
                isRunning = true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start notify-only RecordingService", e)
                isRunning = false
            }
        }

        fun start(context: Context) {
            val intent = Intent(context, RecordingService::class.java).apply {
                action = ACTION_START
            }
            try {
                context.startForegroundService(intent)
                isRunning = true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start RecordingService", e)
                isRunning = false
                listeners.forEach {
                    it.onRecordingStarted(
                        CallRecorder.StartResult(
                            started = false,
                            path = null,
                            source = null,
                            error = e.message ?: "ForegroundService start failed",
                        ),
                    )
                }
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, RecordingService::class.java).apply {
                action = ACTION_STOP
            }
            try {
                context.startService(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop RecordingService", e)
            }
            isRunning = false
        }
    }
}
