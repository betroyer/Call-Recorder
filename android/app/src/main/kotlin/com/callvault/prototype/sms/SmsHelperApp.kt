package com.callvault.prototype.sms

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.provider.Telephony
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import androidx.core.content.ContextCompat
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * Context-based SMS sender used by [ScheduledBlastReceiver] (no Activity).
 */
class SmsHelperApp(private val context: Context) {
    private val cancelFlag = AtomicBoolean(false)

    fun cancelBlast() {
        cancelFlag.set(true)
    }

    fun sendSms(
        address: String,
        body: String,
        subscriptionId: Int = -1,
    ): Map<String, Any?> {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.SEND_SMS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return mapOf("ok" to false, "status" to "failed", "error" to "SEND_SMS permission required", "address" to address)
        }
        return try {
            val sms = smsManagerFor(subscriptionId)
            val code = requestCode.incrementAndGet()
            val sent = PendingIntent.getBroadcast(
                context,
                code,
                Intent(SmsHelper.ACTION_SMS_SENT).putExtra("address", address),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val delivered = PendingIntent.getBroadcast(
                context,
                code + 100000,
                Intent(SmsHelper.ACTION_SMS_DELIVERED).putExtra("address", address),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val parts = sms.divideMessage(body)
            if (parts != null && parts.size > 1) {
                val sentIntents = ArrayList<PendingIntent>()
                val delIntents = ArrayList<PendingIntent>()
                repeat(parts.size) {
                    sentIntents.add(sent)
                    delIntents.add(delivered)
                }
                sms.sendMultipartTextMessage(address, null, parts, sentIntents, delIntents)
            } else {
                sms.sendTextMessage(address, null, body, sent, delivered)
            }
            writeToSentBox(address, body)
            mapOf("ok" to true, "status" to "sent", "address" to address, "subscriptionId" to subscriptionId)
        } catch (e: Exception) {
            mapOf("ok" to false, "status" to "failed", "error" to (e.message ?: "send failed"), "address" to address)
        }
    }

    fun sendBlast(
        addresses: List<String>,
        body: String,
        subscriptionId: Int = -1,
        allSims: Boolean = false,
        blastId: String? = null,
    ): Map<String, Any?> {
        cancelFlag.set(false)
        val cleaned = addresses.map { it.trim() }.filter { it.isNotEmpty() }.distinct()
        val simIds = activeSubscriptionIds()
        var sent = 0
        var failed = 0
        val results = mutableListOf<Map<String, Any?>>()
        cleaned.forEachIndexed { index, address ->
            if (cancelFlag.get()) {
                return mapOf(
                    "ok" to false,
                    "blastId" to blastId,
                    "sent" to sent,
                    "failed" to failed,
                    "cancelled" to true,
                    "results" to results,
                )
            }
            val subId = when {
                subscriptionId >= 0 -> subscriptionId
                allSims && simIds.isNotEmpty() -> simIds[index % simIds.size]
                else -> -1
            }
            val result = sendSms(address, body, subId)
            results.add(result)
            if (result["ok"] == true) sent++ else failed++
            try {
                Thread.sleep(400)
            } catch (_: InterruptedException) {
            }
        }
        return mapOf(
            "ok" to (failed == 0),
            "blastId" to blastId,
            "sent" to sent,
            "failed" to failed,
            "total" to cleaned.size,
            "cancelled" to false,
            "results" to results,
        )
    }

    private fun activeSubscriptionIds(): List<Int> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) return emptyList()
        val sm = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
            ?: return emptyList()
        return try {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_STATE) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                emptyList()
            } else {
                sm.activeSubscriptionInfoList?.map { it.subscriptionId } ?: emptyList()
            }
        } catch (_: SecurityException) {
            emptyList()
        }
    }

    private fun smsManagerFor(subscriptionId: Int): SmsManager {
        return if (subscriptionId >= 0 && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
    }

    private fun writeToSentBox(address: String, body: String) {
        try {
            val values = ContentValues().apply {
                put(Telephony.Sms.ADDRESS, address)
                put(Telephony.Sms.BODY, body)
                put(Telephony.Sms.DATE, System.currentTimeMillis())
                put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_SENT)
                put(Telephony.Sms.READ, 1)
            }
            context.contentResolver.insert(Uri.parse("content://sms/sent"), values)
        } catch (_: Exception) {
        }
    }

    companion object {
        private val requestCode = AtomicInteger(9000)
    }
}
