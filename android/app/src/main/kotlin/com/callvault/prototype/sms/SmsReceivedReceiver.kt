package com.callvault.prototype.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Secondary SMS_RECEIVED signal (works even when not default SMS).
 * Does not write the provider — the default SMS app owns that when we are not default.
 * Notifies Flutter / shows a heads-up when possible.
 */
class SmsReceivedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        // Avoid duplicate write/notify when we are also the default (SMS_DELIVER handles it).
        if (Telephony.Sms.getDefaultSmsPackage(context) == context.packageName) return
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (messages.isEmpty()) return
        val address = messages.firstOrNull()?.displayOriginatingAddress ?: ""
        val body = messages.joinToString(separator = "") { it.messageBody ?: "" }
        val date = messages.firstOrNull()?.timestampMillis ?: System.currentTimeMillis()
        SmsNotificationHelper.showIncoming(context, address, body)
        SmsEventHub.emit(
            mapOf(
                "type" to "onSmsChanged",
                "reason" to "received",
                "address" to address,
                "body" to body,
                "dateMs" to date,
            ),
        )
    }
}
