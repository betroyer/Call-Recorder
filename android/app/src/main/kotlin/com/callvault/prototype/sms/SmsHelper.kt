package com.callvault.prototype.sms

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.app.role.RoleManager
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
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * Native SMS helpers: send, blast w/ progress+cancel, contacts, schedule, ROLE_SMS.
 */
class SmsHelper(private val activity: Activity) {
    fun hasSendPermission(): Boolean =
        ContextCompat.checkSelfPermission(activity, Manifest.permission.SEND_SMS) ==
            PackageManager.PERMISSION_GRANTED

    fun hasReadPermission(): Boolean =
        ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED

    fun hasContactsPermission(): Boolean =
        ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED

    fun listSims(): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()
        result.add(mapOf("id" to -1, "label" to "ALL SIMs", "slot" to -1))
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) return result
        val sm = activity.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
            ?: return result
        val list = try {
            if (ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_PHONE_STATE) ==
                PackageManager.PERMISSION_GRANTED
            ) {
                sm.activeSubscriptionInfoList
            } else null
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

    fun isDefaultSmsApp(): Boolean {
        return try {
            Telephony.Sms.getDefaultSmsPackage(activity) == activity.packageName
        } catch (_: Exception) {
            false
        }
    }

    fun requestDefaultSmsRole(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val rm = activity.getSystemService(RoleManager::class.java) ?: return false
            if (!rm.isRoleAvailable(RoleManager.ROLE_SMS)) return false
            if (rm.isRoleHeld(RoleManager.ROLE_SMS)) return true
            val intent = rm.createRequestRoleIntent(RoleManager.ROLE_SMS)
            activity.startActivityForResult(intent, REQ_SMS_ROLE)
            return true
        }
        val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
            .putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, activity.packageName)
        return try {
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    fun openMmsComposer(addresses: List<String>, body: String): Boolean {
        return try {
            val uri = Uri.parse("smsto:" + addresses.joinToString(";"))
            val intent = Intent(Intent.ACTION_SENDTO, uri).apply {
                putExtra("sms_body", body)
            }
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    fun listContacts(limit: Int = 500): List<Map<String, Any?>> {
        if (!hasContactsPermission()) return emptyList()
        val items = mutableListOf<Map<String, Any?>>()
        val cursor = try {
            activity.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                ),
                null,
                null,
                "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC",
            )
        } catch (_: SecurityException) {
            null
        } ?: return emptyList()

        val seen = HashSet<String>()
        cursor.use {
            while (it.moveToNext() && items.size < limit) {
                val name = it.getString(0) ?: ""
                val number = (it.getString(1) ?: "").replace(" ", "").trim()
                if (number.isEmpty() || !seen.add(number)) continue
                items.add(mapOf("name" to name, "number" to number))
            }
        }
        return items
    }

    fun listInbox(limit: Int = 100): List<Map<String, Any?>> {
        if (!hasReadPermission()) return emptyList()
        val items = mutableListOf<Map<String, Any?>>()
        val cursor: Cursor? = try {
            activity.contentResolver.query(
                Telephony.Sms.Inbox.CONTENT_URI,
                arrayOf(
                    Telephony.Sms._ID,
                    Telephony.Sms.ADDRESS,
                    Telephony.Sms.BODY,
                    Telephony.Sms.DATE,
                    Telephony.Sms.READ,
                ),
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

    fun sendSms(
        address: String,
        body: String,
        subscriptionId: Int = -1,
    ): Map<String, Any?> {
        if (!hasSendPermission()) {
            return mapOf(
                "ok" to false,
                "status" to "failed",
                "error" to "SEND_SMS permission required",
                "address" to address,
            )
        }
        if (address.isBlank() || body.isBlank()) {
            return mapOf(
                "ok" to false,
                "status" to "failed",
                "error" to "Address and body required",
                "address" to address,
            )
        }
        return try {
            val sms = smsManagerFor(subscriptionId)
            val code = requestCode.incrementAndGet()
            val sent = PendingIntent.getBroadcast(
                activity,
                code,
                Intent(ACTION_SMS_SENT).putExtra("address", address),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val delivered = PendingIntent.getBroadcast(
                activity,
                code + 100000,
                Intent(ACTION_SMS_DELIVERED).putExtra("address", address),
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
            mapOf(
                "ok" to true,
                "status" to "sent",
                "address" to address,
                "subscriptionId" to subscriptionId,
                "error" to null,
            )
        } catch (e: Exception) {
            mapOf(
                "ok" to false,
                "status" to "failed",
                "error" to (e.message ?: "send failed"),
                "address" to address,
            )
        }
    }

    fun cancelBlast() {
        cancelFlag.set(true)
    }

    fun sendBlast(
        addresses: List<String>,
        body: String,
        subscriptionId: Int = -1,
        allSims: Boolean = false,
        blastId: String? = null,
        onProgress: ((Map<String, Any?>) -> Unit)? = null,
    ): Map<String, Any?> {
        cancelFlag.set(false)
        if (!hasSendPermission()) {
            return mapOf(
                "ok" to false,
                "error" to "SEND_SMS permission required",
                "sent" to 0,
                "failed" to 0,
                "cancelled" to false,
                "results" to emptyList<Map<String, Any?>>(),
            )
        }
        val cleaned = addresses.map { it.trim() }.filter { it.isNotEmpty() }.distinct()
        if (cleaned.isEmpty()) {
            return mapOf(
                "ok" to false,
                "error" to "No recipients",
                "sent" to 0,
                "failed" to 0,
                "results" to emptyList<Map<String, Any?>>(),
            )
        }
        if (body.isBlank()) {
            return mapOf(
                "ok" to false,
                "error" to "Empty message",
                "sent" to 0,
                "failed" to 0,
                "results" to emptyList<Map<String, Any?>>(),
            )
        }

        val id = blastId ?: UUID.randomUUID().toString()
        val simIds = activeSubscriptionIds()
        var sent = 0
        var failed = 0
        var cancelled = false
        val results = mutableListOf<Map<String, Any?>>()

        cleaned.forEachIndexed { index, address ->
            if (cancelFlag.get()) {
                cancelled = true
                onProgress?.invoke(
                    mapOf(
                        "type" to "onBlastProgress",
                        "blastId" to id,
                        "index" to index,
                        "total" to cleaned.size,
                        "address" to address,
                        "status" to "cancelled",
                        "sent" to sent,
                        "failed" to failed,
                        "done" to true,
                        "cancelled" to true,
                    ),
                )
                return@forEachIndexed
            }
            val subId = when {
                subscriptionId >= 0 -> subscriptionId
                allSims && simIds.isNotEmpty() -> simIds[index % simIds.size]
                else -> -1
            }
            val result = sendSms(address, body, subId).toMutableMap()
            result["index"] = index
            results.add(result)
            if (result["ok"] == true) sent++ else failed++

            onProgress?.invoke(
                mapOf(
                    "type" to "onBlastProgress",
                    "blastId" to id,
                    "index" to index,
                    "total" to cleaned.size,
                    "address" to address,
                    "status" to result["status"],
                    "error" to result["error"],
                    "sent" to sent,
                    "failed" to failed,
                    "done" to false,
                    "cancelled" to false,
                ),
            )
            try {
                Thread.sleep(400)
            } catch (_: InterruptedException) {
            }
        }

        if (cancelled) {
            // Mark remaining as skipped
            for (i in results.size until cleaned.size) {
                results.add(
                    mapOf(
                        "ok" to false,
                        "status" to "cancelled",
                        "address" to cleaned[i],
                        "error" to "Cancelled",
                        "index" to i,
                    ),
                )
            }
        }

        onProgress?.invoke(
            mapOf(
                "type" to "onBlastProgress",
                "blastId" to id,
                "index" to cleaned.size,
                "total" to cleaned.size,
                "sent" to sent,
                "failed" to failed,
                "done" to true,
                "cancelled" to cancelled,
            ),
        )

        return mapOf(
            "ok" to (!cancelled && failed == 0),
            "blastId" to id,
            "sent" to sent,
            "failed" to failed,
            "total" to cleaned.size,
            "cancelled" to cancelled,
            "results" to results,
        )
    }

    fun scheduleBlast(
        addresses: List<String>,
        body: String,
        triggerAtMs: Long,
        subscriptionId: Int,
        allSims: Boolean,
        priority: String,
    ): Map<String, Any?> {
        if (triggerAtMs <= System.currentTimeMillis() + 5_000) {
            return mapOf("ok" to false, "error" to "Schedule time must be at least 5 seconds ahead")
        }
        val jobId = UUID.randomUUID().toString()
        val prefs = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = JSONArray(prefs.getString(KEY_SCHEDULED, "[]"))
        val obj = JSONObject()
            .put("id", jobId)
            .put("body", body)
            .put("triggerAtMs", triggerAtMs)
            .put("subscriptionId", subscriptionId)
            .put("allSims", allSims)
            .put("priority", priority)
            .put("addresses", JSONArray(addresses))
        arr.put(obj)
        prefs.edit().putString(KEY_SCHEDULED, arr.toString()).apply()

        val am = activity.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(activity, ScheduledBlastReceiver::class.java).apply {
            action = ACTION_SCHEDULED_BLAST
            putExtra("jobId", jobId)
        }
        val pi = PendingIntent.getBroadcast(
            activity,
            jobId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
            } else {
                @Suppress("DEPRECATION")
                am.setExact(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
            }
        } catch (e: SecurityException) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
            } else {
                @Suppress("DEPRECATION")
                am.set(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
            }
        } catch (e: Exception) {
            return mapOf("ok" to false, "error" to (e.message ?: "schedule failed"))
        }
        return mapOf("ok" to true, "jobId" to jobId, "triggerAtMs" to triggerAtMs)
    }

    fun listScheduledBlasts(): List<Map<String, Any?>> {
        val prefs = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = JSONArray(prefs.getString(KEY_SCHEDULED, "[]"))
        val out = mutableListOf<Map<String, Any?>>()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val addresses = mutableListOf<String>()
            val a = o.getJSONArray("addresses")
            for (j in 0 until a.length()) addresses.add(a.getString(j))
            out.add(
                mapOf(
                    "id" to o.getString("id"),
                    "body" to o.getString("body"),
                    "triggerAtMs" to o.getLong("triggerAtMs"),
                    "subscriptionId" to o.optInt("subscriptionId", -1),
                    "allSims" to o.optBoolean("allSims", false),
                    "priority" to o.optString("priority", "Low"),
                    "addresses" to addresses,
                    "count" to addresses.size,
                ),
            )
        }
        return out.sortedBy { it["triggerAtMs"] as Long }
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
        }
    }

    companion object {
        private val requestCode = AtomicInteger(6000)
        private val cancelFlag = AtomicBoolean(false)
        const val PREFS = "callvault_sms"
        const val KEY_SCHEDULED = "scheduled_blasts"
        const val ACTION_SMS_SENT = "com.callvault.prototype.SMS_SENT"
        const val ACTION_SMS_DELIVERED = "com.callvault.prototype.SMS_DELIVERED"
        const val ACTION_SCHEDULED_BLAST = "com.callvault.prototype.SCHEDULED_BLAST"
        const val REQ_SMS_ROLE = 4402

        fun takeScheduledJob(context: Context, jobId: String): JSONObject? {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val arr = JSONArray(prefs.getString(KEY_SCHEDULED, "[]"))
            val next = JSONArray()
            var found: JSONObject? = null
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                if (o.getString("id") == jobId) {
                    found = o
                } else {
                    next.put(o)
                }
            }
            prefs.edit().putString(KEY_SCHEDULED, next.toString()).apply()
            return found
        }
    }
}
