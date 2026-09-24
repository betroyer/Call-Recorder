package com.callvault.prototype.sms

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.provider.Telephony
import android.telephony.SmsMessage

object SmsInboxWriter {
    fun writeIncoming(context: Context, messages: Array<SmsMessage>): Map<String, Any?> {
        if (messages.isEmpty()) {
            return mapOf("ok" to false, "error" to "empty")
        }
        val address = messages.firstOrNull()?.displayOriginatingAddress ?: ""
        val body = messages.joinToString(separator = "") { it.messageBody ?: "" }
        val date = messages.firstOrNull()?.timestampMillis ?: System.currentTimeMillis()
        return try {
            val values = ContentValues().apply {
                put(Telephony.Sms.ADDRESS, address)
                put(Telephony.Sms.BODY, body)
                put(Telephony.Sms.DATE, date)
                put(Telephony.Sms.DATE_SENT, date)
                put(Telephony.Sms.READ, 0)
                put(Telephony.Sms.SEEN, 0)
                put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_INBOX)
            }
            val uri = context.contentResolver.insert(Telephony.Sms.Inbox.CONTENT_URI, values)
                ?: context.contentResolver.insert(Uri.parse("content://sms/inbox"), values)
            mapOf(
                "ok" to (uri != null),
                "address" to address,
                "body" to body,
                "dateMs" to date,
                "uri" to uri?.toString(),
            )
        } catch (e: Exception) {
            mapOf("ok" to false, "error" to (e.message ?: "insert failed"), "address" to address)
        }
    }
}
