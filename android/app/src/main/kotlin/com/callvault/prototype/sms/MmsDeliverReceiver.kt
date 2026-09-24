package com.callvault.prototype.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Stub MMS/WAP deliver receiver required for default SMS role eligibility.
 * Full MMS persistence is out of scope for this prototype; we still acknowledge delivery.
 */
class MmsDeliverReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.WAP_PUSH_DELIVER_ACTION) return
        SmsEventHub.emit(
            mapOf(
                "type" to "onSmsChanged",
                "reason" to "mms_deliver",
            ),
        )
    }
}
