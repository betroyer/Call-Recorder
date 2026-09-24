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
import android.provider.Telephony
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import androidx.core.content.ContextCompat
import java.util.concurrent.atomic.AtomicInteger

/**
 * Native SMS send / inbox helpers for CallVault.
 */
class SmsHelper(private val activity: Activity) {
    fun hasSendPermission(): Boolean =
        ContextCompat.checkSelfPermission(activity, Manifest.permission.SEND_SMS) ==
            PackageManager.PERMISSION_GRANTED

    fun hasReadPermission(): Boolean =
        ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED

    fun listSims(): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()
        result.add(mapOf("id" to -1, "label" to "ALL SIMs", "slot" to -1))
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) {
            return result
        }
        val sm = activity.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
            ?: return result
        val list = try {
            if (ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_PHONE_STATE) ==
                PackageManager.PERMISSION_GRANTED
            ) {
                sm.activeSubscriptionInfoList
            } else {
                null
            }
        } catch (_: SecurityException) {
            null
        }
        list?.forEach { info ->
            val label = info.displayName?.toString()?.ifBlank { "SIM ${info.simSlotIndex + 1}" }
                ?: "SIM ${info.simSlotIndex + 1}"
            result.add(
                mapOf(
                    "id" to info.subscriptionId,
                    "label" to label,
                    "slot" to info.simSlotIndex,
                    "number" to info.number,
                ),
            )
        }
        return result
    }

    fun listInbox(limit: Int = 100): List<Map<String, Any?>> {
        if (!hasReadPermission()) return emptyList()
        val items = mutableListOf<Map<String, Any?>>()
        val uri = Telephony.Sms.Inbox.CONTENT_URI
        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.READ,
            Telephony.Sms.TYPE,
        )
        val cursor: Cursor? = try {
            activity.contentResolver.query(
                uri,
                projection,
                null,
                null,
                "${Telephony.Sms.DATE} DESC",
            )
        } catch (_: SecurityException) {
            null
        }
        cursor?.use {
            var count = 0
            while (it.moveToNext() && count < limit) {
                items.add(
                    mapOf(
                        "id" to it.getLong(0),
                        "address" to (it.getString(1) ?: ""),
                        "body" to (it.getString(2) ?: ""),
                        "dateMs" to it.getLong(3),
                        "read" to (it.getInt(4) == 1),
                        "type" to "inbox",
                    ),
                )
                count++
            }
        }
        return items
    }

    fun listConversations(limit: Int = 80): List<Map<String, Any?>> {
        if (!hasReadPermission()) return emptyList()
        val uri = Telephony.Sms.CONTENT_URI
        val cursor = try {
            activity.contentResolver.query(
                uri,
                arrayOf(
                    Telephony.Sms._ID,
                    Telephony.Sms.ADDRESS,
                    Telephony.Sms.BODY,
                    Telephony.Sms.DATE,
                    Telephony.Sms.TYPE,
                ),
                null,
                null,
                "${Telephony.Sms.DATE} DESC",
            )
        } catch (_: SecurityException) {
            null
        } ?: return emptyList()

        val byAddress = linkedMapOf<String, Map<String, Any?>>()
        cursor.use {
            while (it.moveToNext() && byAddress.size < limit) {
                val address = it.getString(1)?.trim().orEmpty()
                if (address.isEmpty() || byAddress.containsKey(address)) continue
                byAddress[address] = mapOf(
                    "address" to address,
                    "body" to (it.getString(2) ?: ""),
                    "dateMs" to it.getLong(3),
                    "type" to when (it.getInt(4)) {
                        Telephony.Sms.MESSAGE_TYPE_INBOX -> "inbox"
                        Telephony.Sms.MESSAGE_TYPE_SENT -> "sent"
                        else -> "other"
                    },
                )
            }
        }
        return byAddress.values.toList()
    }

    fun threadMessages(address: String, limit: Int = 200): List<Map<String, Any?>> {
        if (!hasReadPermission()) return emptyList()
        val items = mutableListOf<Map<String, Any?>>()
        val cursor = try {
            activity.contentResolver.query(
                Telephony.Sms.CONTENT_URI,
                arrayOf(
                    Telephony.Sms._ID,
                    Telephony.Sms.ADDRESS,
                    Telephony.Sms.BODY,
                    Telephony.Sms.DATE,
                    Telephony.Sms.TYPE,
                ),
                "${Telephony.Sms.ADDRESS}=?",
                arrayOf(address),
                "${Telephony.Sms.DATE} ASC",
            )
        } catch (_: SecurityException) {
            null
        } ?: return emptyList()

        cursor.use {
            var count = 0
            while (it.moveToNext() && count < limit) {
                items.add(
                    mapOf(
                        "id" to it.getLong(0),
                        "address" to (it.getString(1) ?: address),
                        "body" to (it.getString(2) ?: ""),
                        "dateMs" to it.getLong(3),
                        "type" to when (it.getInt(4)) {
                            Telephony.Sms.MESSAGE_TYPE_INBOX -> "inbox"
                            Telephony.Sms.MESSAGE_TYPE_SENT -> "sent"
                            else -> "other"
                        },
                    ),
                )
                count++
            }
        }
        return items
    }

    /**
     * @param subscriptionId -1 = default / rotate across SIMs for blast
     * @param allSims when true and multiple recipients, split across SIMs
     */
    fun sendSms(
        address: String,
        body: String,
        subscriptionId: Int = -1,
    ): Map<String, Any?> {
        if (!hasSendPermission()) {
            return mapOf("ok" to false, "error" to "SEND_SMS permission required")
        }
        if (address.isBlank() || body.isBlank()) {
            return mapOf("ok" to false, "error" to "Address and body required")
        }
        return try {
            val sms = smsManagerFor(subscriptionId)
            val sent = PendingIntent.getBroadcast(
                activity,
                requestCode.incrementAndGet(),
                Intent("com.callvault.prototype.SMS_SENT"),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val parts = sms.divideMessage(body)
            if (parts != null && parts.size > 1) {
                val sentIntents = ArrayList<PendingIntent>()
                repeat(parts.size) { sentIntents.add(sent) }
                sms.sendMultipartTextMessage(address, null, parts, sentIntents, null)
            } else {
                sms.sendTextMessage(address, null, body, sent, null)
            }
            writeToSentBox(address, body)
            mapOf("ok" to true, "address" to address, "subscriptionId" to subscriptionId)
        } catch (e: Exception) {
            mapOf("ok" to false, "error" to (e.message ?: "send failed"), "address" to address)
        }
    }

    fun sendBlast(
        addresses: List<String>,
        body: String,
        subscriptionId: Int = -1,
        allSims: Boolean = false,
    ): Map<String, Any?> {
        if (!hasSendPermission()) {
            return mapOf("ok" to false, "error" to "SEND_SMS permission required", "sent" to 0, "failed" to 0)
        }
        val cleaned = addresses.map { it.trim() }.filter { it.isNotEmpty() }.distinct()
        if (cleaned.isEmpty()) {
            return mapOf("ok" to false, "error" to "No recipients", "sent" to 0, "failed" to 0)
        }
        if (body.isBlank()) {
            return mapOf("ok" to false, "error" to "Empty message", "sent" to 0, "failed" to 0)
        }

        val simIds = activeSubscriptionIds()
        var sent = 0
        var failed = 0
        val errors = mutableListOf<String>()

        cleaned.forEachIndexed { index, address ->
            val subId = when {
                subscriptionId >= 0 -> subscriptionId
                allSims && simIds.isNotEmpty() -> simIds[index % simIds.size]
                else -> -1
            }
            val result = sendSms(address, body, subId)
            if (result["ok"] == true) {
                sent++
            } else {
                failed++
                errors.add("$address: ${result["error"]}")
            }
            // Small pacing to reduce modem overload on large blasts.
            try {
                Thread.sleep(350)
            } catch (_: InterruptedException) {
            }
        }

        return mapOf(
            "ok" to (failed == 0),
            "sent" to sent,
            "failed" to failed,
            "total" to cleaned.size,
            "errors" to errors.take(10),
        )
    }

    private fun activeSubscriptionIds(): List<Int> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) return emptyList()
        val sm = activity.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
            ?: return emptyList()
        return try {
            if (ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_PHONE_STATE) !=
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
            activity.contentResolver.insert(Uri.parse("content://sms/sent"), values)
        } catch (_: Exception) {
            // Not default SMS app — insert may fail; send still succeeded.
        }
    }

    companion object {
        private val requestCode = AtomicInteger(6000)
    }
}
