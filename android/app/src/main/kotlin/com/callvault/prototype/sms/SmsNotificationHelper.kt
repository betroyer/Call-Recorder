package com.callvault.prototype.sms

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.callvault.prototype.MainActivity

object SmsNotificationHelper {
    private const val CHANNEL_ID = "callvault_sms_inbox"
    private const val NOTIFICATION_ID_BASE = 7100

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Incoming SMS",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "New text messages from customers and contacts"
        }
        manager.createNotificationChannel(channel)
    }

    fun showIncoming(context: Context, address: String, body: String) {
        ensureChannel(context)
        val open = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("open_inbox", true)
        }
        val pending = PendingIntent.getActivity(
            context,
            address.hashCode(),
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentTitle(address.ifBlank { "New message" })
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(
                NOTIFICATION_ID_BASE + (address.hashCode() and 0xFFFF),
                notification,
            )
        } catch (_: SecurityException) {
        }
    }
}
