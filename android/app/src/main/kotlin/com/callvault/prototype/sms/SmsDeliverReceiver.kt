package com.callvault.prototype.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Receives SMS_DELIVER when CallVault is the default SMS app and persists inbox rows.
 */
class SmsDeliverReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.SMS_DELIVER_ACTION) return
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        val result = SmsInboxWriter.writeIncoming(context, messages)
        val address = result["address"]?.toString().orEmpty()
        val body = result["body"]?.toString().orEmpty()
        if (result["ok"] == true) {
            SmsNotificationHelper.showIncoming(context, address, body)
            SmsEventHub.emit(
                mapOf(
                    "type" to "onSmsChanged",
                    "reason" to "deliver",
                    "address" to address,
                    "body" to body,
                    "dateMs" to result["dateMs"],
                ),
            )
        }
    }
}
