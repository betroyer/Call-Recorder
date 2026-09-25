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
        val lastOk = lastSuccessfulSmsSubId()
        val defaultSms = defaultSmsSubscriptionId()
        result.add(
            mapOf(
                "id" to -1,
                "label" to "Auto — try SIM with load",
                "slot" to -1,
                "preferred" to true,
                "hint" to "Uses last working SIM, then SMS-default, then others",
            ),
        )
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
            val slot = info.simSlotIndex + 1
            val name = info.displayName?.toString()?.ifBlank { null }
                ?: info.carrierName?.toString()?.ifBlank { null }
                ?: "SIM $slot"
            val tags = mutableListOf<String>()
            if (info.subscriptionId == defaultSms) tags.add("SMS default")
            if (info.subscriptionId == lastOk) tags.add("has load / last OK")
            val number = info.number?.takeIf { it.isNotBlank() }
            val label = buildString {
                append("SIM $slot · $name")
                if (number != null) append(" · $number")
                if (tags.isNotEmpty()) append(" (${tags.joinToString(", ")})")
            }
            result.add(
                mapOf(
                    "id" to info.subscriptionId,
                    "label" to label,
                    "slot" to info.simSlotIndex,
                    "number" to number,
                    "carrier" to (info.carrierName?.toString() ?: ""),
                    "isDefaultSms" to (info.subscriptionId == defaultSms),
                    "lastSuccessful" to (info.subscriptionId == lastOk),
                ),
            )
        }
        return result
    }

    private fun defaultSmsSubscriptionId(): Int {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                SubscriptionManager.getDefaultSmsSubscriptionId()
            } else {
                -1
            }
        } catch (_: Exception) {
            -1
        }
    }

    private fun lastSuccessfulSmsSubId(): Int {
        return activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getInt(KEY_LAST_SMS_SUB, -1)
    }

    private fun rememberSuccessfulSmsSubId(subscriptionId: Int) {
        if (subscriptionId < 0) return
        activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putInt(KEY_LAST_SMS_SUB, subscriptionId)
            .apply()
    }

    /** Order of SIMs to try when Auto is selected (or for failover). */
    private fun subscriptionTryOrder(preferredId: Int): List<Int> {
        val active = activeSubscriptionIds()
        if (active.isEmpty()) {
            val defSms = defaultSmsSubscriptionId()
            return when {
                preferredId >= 0 -> listOf(preferredId)
                defSms >= 0 -> listOf(defSms)
                else -> listOf(-1)
            }
        }
        val ordered = linkedSetOf<Int>()
        if (preferredId >= 0 && active.contains(preferredId)) {
            ordered.add(preferredId)
        }
        val lastOk = lastSuccessfulSmsSubId()
        if (lastOk >= 0 && active.contains(lastOk)) ordered.add(lastOk)
        val defSms = defaultSmsSubscriptionId()
        if (defSms >= 0 && active.contains(defSms)) ordered.add(defSms)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val dataId = SubscriptionManager.getDefaultDataSubscriptionId()
                if (dataId >= 0 && active.contains(dataId)) ordered.add(dataId)
            }
        } catch (_: Exception) {
        }
        active.forEach { ordered.add(it) }
        return ordered.toList()
    }

    private fun forgetSuccessfulSmsSubId(subscriptionId: Int) {
        if (subscriptionId < 0) return
        val prefs = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (prefs.getInt(KEY_LAST_SMS_SUB, -1) == subscriptionId) {
            prefs.edit().remove(KEY_LAST_SMS_SUB).apply()
        }
    }

    private fun shouldRetryOnOtherSim(resultCode: Int): Boolean {
        // Modem / network / no-service failures often mean the wrong SIM (no load).
        return when (resultCode) {
            SmsManager.RESULT_ERROR_GENERIC_FAILURE,
            SmsManager.RESULT_ERROR_NO_SERVICE,
            SmsManager.RESULT_ERROR_RADIO_OFF,
            16, // RESULT_MODEM_ERROR
            17, // RESULT_NETWORK_ERROR
            124, 111, 105,
            -> true
            else -> resultCode in 100..130 // many RESULT_RIL_* codes
        }
    }

    fun isDefaultSmsApp(): Boolean {
        try {
            if (Telephony.Sms.getDefaultSmsPackage(activity) == activity.packageName) {
                return true
            }
        } catch (_: Exception) {
        }
        // Some OEMs lag getDefaultSmsPackage after the role grant; RoleManager is authoritative on Q+.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val rm = activity.getSystemService(RoleManager::class.java)
                if (rm != null && rm.isRoleHeld(RoleManager.ROLE_SMS)) return true
            } catch (_: Exception) {
            }
        }
        return false
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
                val number = (it.getString(1) ?: "").trim()
                if (number.isEmpty()) continue
                val key = PhoneNormalizer.matchKey(number)
                if (key.isEmpty() || !seen.add(key)) continue
                items.add(
                    mapOf(
                        "name" to name,
                        "number" to PhoneNormalizer.normalize(number),
                        "matchKey" to key,
                    ),
                )
            }
        }
        return items
    }

    fun resolveContactName(address: String): String? {
        if (address.isBlank() || !hasContactsPermission()) return null
        val key = PhoneNormalizer.matchKey(address)
        if (key.isEmpty()) return null
        return contactNameByKey()[key]
    }

    private fun contactNameByKey(): Map<String, String> {
        if (!hasContactsPermission()) return emptyMap()
        val map = linkedMapOf<String, String>()
        val cursor = try {
            activity.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                ),
                null,
                null,
                null,
            )
        } catch (_: SecurityException) {
            null
        } ?: return emptyMap()

        cursor.use {
            while (it.moveToNext()) {
                val name = it.getString(0)?.trim().orEmpty()
                val number = it.getString(1)?.trim().orEmpty()
                if (name.isEmpty() || number.isEmpty()) continue
                val key = PhoneNormalizer.matchKey(number)
                if (key.isNotEmpty()) {
                    map.putIfAbsent(key, name)
                }
            }
        }
        return map
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

    fun setMessageRead(id: Long, read: Boolean): Map<String, Any?> {
        if (!hasReadPermission()) {
            return mapOf("ok" to false, "error" to "READ_SMS permission required")
        }
        return try {
            val values = ContentValues().apply {
                put(Telephony.Sms.READ, if (read) 1 else 0)
                put(Telephony.Sms.SEEN, if (read) 1 else 0)
            }
            val updated = activity.contentResolver.update(
                Telephony.Sms.CONTENT_URI,
                values,
                "${Telephony.Sms._ID}=?",
                arrayOf(id.toString()),
            )
            if (updated <= 0) {
                mapOf(
                    "ok" to false,
                    "error" to "Could not update (try Set as default SMS app)",
                    "updated" to 0,
                )
            } else {
                mapOf("ok" to true, "updated" to updated, "read" to read, "id" to id)
            }
        } catch (e: SecurityException) {
            mapOf(
                "ok" to false,
                "error" to "Blocked — set PYX Food Products as default SMS app to change read state",
            )
        } catch (e: Exception) {
            mapOf("ok" to false, "error" to (e.message ?: "update failed"))
        }
    }

    fun setThreadRead(address: String, read: Boolean): Map<String, Any?> {
        if (!hasReadPermission()) {
            return mapOf("ok" to false, "error" to "READ_SMS permission required")
        }
        if (address.isBlank()) {
            return mapOf("ok" to false, "error" to "Address required")
        }
        return try {
            val values = ContentValues().apply {
                put(Telephony.Sms.READ, if (read) 1 else 0)
                put(Telephony.Sms.SEEN, if (read) 1 else 0)
            }
            val updated = activity.contentResolver.update(
                Telephony.Sms.CONTENT_URI,
                values,
                "${Telephony.Sms.ADDRESS}=?",
                arrayOf(address),
            )
            if (updated <= 0) {
                mapOf(
                    "ok" to false,
                    "error" to "Could not update (try Set as default SMS app)",
                    "updated" to 0,
                )
            } else {
                mapOf("ok" to true, "updated" to updated, "read" to read, "address" to address)
            }
        } catch (e: SecurityException) {
            mapOf(
                "ok" to false,
                "error" to "Blocked — set PYX Food Products as default SMS app to change read state",
            )
        } catch (e: Exception) {
            mapOf("ok" to false, "error" to (e.message ?: "update failed"))
        }
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
                    Telephony.Sms.READ,
                ),
                null,
                null,
                "${Telephony.Sms.DATE} DESC",
            )
        } catch (_: SecurityException) {
            null
        } ?: return emptyList()

        val byKey = linkedMapOf<String, MutableMap<String, Any?>>()
        val unreadByKey = mutableMapOf<String, Int>()
        cursor.use {
            while (it.moveToNext()) {
                val address = it.getString(1)?.trim().orEmpty()
                if (address.isEmpty()) continue
                val key = conversationKey(address)
                val type = it.getInt(4)
                val read = it.getInt(5) == 1
                if (type == Telephony.Sms.MESSAGE_TYPE_INBOX && !read) {
                    unreadByKey[key] = (unreadByKey[key] ?: 0) + 1
                }
                if (!byKey.containsKey(key) && byKey.size < limit) {
                    byKey[key] = mutableMapOf(
                        "id" to it.getLong(0),
                        "address" to PhoneNormalizer.normalize(address),
                        "body" to (it.getString(2) ?: ""),
                        "dateMs" to it.getLong(3),
                        "type" to when (type) {
                            Telephony.Sms.MESSAGE_TYPE_INBOX -> "inbox"
                            Telephony.Sms.MESSAGE_TYPE_SENT -> "sent"
                            else -> "other"
                        },
                    )
                }
            }
        }
        val names = contactNameByKey()
        return byKey.map { (key, row) ->
            val unread = unreadByKey[key] ?: 0
            row["unreadCount"] = unread
            row["read"] = unread == 0
            row["contactName"] = names[key]
            row
        }
    }

    private fun conversationKey(address: String): String {
        return PhoneNormalizer.matchKey(address).ifEmpty { address.trim() }
    }

    fun threadMessages(address: String, limit: Int = 200): List<Map<String, Any?>> {
        if (!hasReadPermission()) return emptyList()
        val variants = addressVariants(address)
        if (variants.isEmpty()) return emptyList()
        val items = mutableListOf<Map<String, Any?>>()
        val placeholders = variants.joinToString(",") { "?" }
        val cursor = try {
            activity.contentResolver.query(
                Telephony.Sms.CONTENT_URI,
                arrayOf(
                    Telephony.Sms._ID,
                    Telephony.Sms.ADDRESS,
                    Telephony.Sms.BODY,
                    Telephony.Sms.DATE,
                    Telephony.Sms.TYPE,
                    Telephony.Sms.STATUS,
                ),
                "${Telephony.Sms.ADDRESS} IN ($placeholders)",
                variants.toTypedArray(),
                "${Telephony.Sms.DATE} ASC",
            )
        } catch (_: SecurityException) {
            null
        } ?: return emptyList()

        cursor.use {
            var count = 0
            while (it.moveToNext() && count < limit) {
                val type = it.getInt(4)
                val deliveryStatus = it.getInt(5)
                val typeLabel = when (type) {
                    Telephony.Sms.MESSAGE_TYPE_INBOX -> "inbox"
                    Telephony.Sms.MESSAGE_TYPE_SENT -> "sent"
                    Telephony.Sms.MESSAGE_TYPE_FAILED -> "failed"
                    Telephony.Sms.MESSAGE_TYPE_OUTBOX -> "outbox"
                    Telephony.Sms.MESSAGE_TYPE_QUEUED -> "queued"
                    else -> "other"
                }
                val statusLabel = when {
                    type == Telephony.Sms.MESSAGE_TYPE_FAILED -> "failed"
                    type == Telephony.Sms.MESSAGE_TYPE_OUTBOX ||
                        type == Telephony.Sms.MESSAGE_TYPE_QUEUED -> "outbox"
                    type == Telephony.Sms.MESSAGE_TYPE_SENT &&
                        deliveryStatus == Telephony.Sms.STATUS_FAILED -> "failed"
                    type == Telephony.Sms.MESSAGE_TYPE_SENT -> "sent"
                    type == Telephony.Sms.MESSAGE_TYPE_INBOX -> "inbox"
                    else -> typeLabel
                }
                items.add(
                    mapOf(
                        "id" to it.getLong(0),
                        "address" to (it.getString(1) ?: address),
                        "body" to (it.getString(2) ?: ""),
                        "dateMs" to it.getLong(3),
                        "type" to typeLabel,
                        "status" to statusLabel,
                    ),
                )
                count++
            }
        }
        return items
    }

    private fun addressVariants(raw: String): List<String> {
        val trimmed = raw.trim()
        val normalized = PhoneNormalizer.normalize(trimmed)
        val digits = normalized.filter { it.isDigit() }
        val set = linkedSetOf<String>()
        if (trimmed.isNotEmpty()) set.add(trimmed)
        if (normalized.isNotEmpty()) set.add(normalized)
        if (digits.isNotEmpty()) set.add(digits)
        if (digits.length == 12 && digits.startsWith("63")) {
            set.add("0${digits.substring(2)}")
            set.add("+$digits")
        }
        if (digits.length == 11 && digits.startsWith("09")) {
            set.add("+63${digits.substring(1)}")
            set.add("63${digits.substring(1)}")
        }
        if (digits.length == 10 && digits.startsWith("9")) {
            set.add("0$digits")
            set.add("+63$digits")
            set.add("63$digits")
        }
        return set.filter { it.isNotEmpty() }.toList()
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
        val normalized = PhoneNormalizer.normalize(address)
        if (normalized.isBlank() || body.isBlank()) {
            return mapOf(
                "ok" to false,
                "status" to "failed",
                "error" to "Address and body required",
                "address" to address,
            )
        }

        // Always prefer the chosen SIM first, but fail over to other slots on modem errors
        // (wrong/empty-load SIM is the most common cause of mass code 16/124 failures).
        val tryOrder = subscriptionTryOrder(subscriptionId)

        var lastFailure: Map<String, Any?> = mapOf(
            "ok" to false,
            "status" to "failed",
            "error" to "No SIM available to send",
            "address" to normalized,
        )
        val attempts = mutableListOf<Map<String, Any?>>()

        for ((index, subId) in tryOrder.withIndex()) {
            val attempt = sendSmsOnSubscription(normalized, body, subId)
            attempts.add(attempt)
            if (attempt["ok"] == true) {
                rememberSuccessfulSmsSubId(subId)
                return attempt + mapOf(
                    "triedSims" to attempts.size,
                    "autoSelected" to (subscriptionId < 0 || attempts.size > 1),
                )
            }
            lastFailure = attempt
            val code = (attempt["resultCode"] as? Number)?.toInt() ?: -1
            if (SmsSentWaiters.isTransientModemError(code)) {
                forgetSuccessfulSmsSubId(subId)
            }
            val moreSims = index < tryOrder.lastIndex
            if (!moreSims || !shouldRetryOnOtherSim(code)) {
                break
            }
            try {
                Thread.sleep(700)
            } catch (_: InterruptedException) {
            }
        }

        val err = lastFailure["error"]?.toString() ?: "Send failed on all SIMs"
        val hint = if (tryOrder.size > 1) {
            " Tried ${attempts.size} SIM(s). Put SMS load on one SIM, pick it under Send via, " +
                "set PYX Food Products as default SMS, then retry."
        } else {
            " Put SMS load on the SIM, set PYX Food Products as default SMS, then retry."
        }
        SmsEventHub.emit(
            mapOf(
                "type" to "onSmsChanged",
                "reason" to "send_failed",
                "address" to normalized,
                "error" to err,
            ),
        )
        return lastFailure + mapOf(
            "error" to (err + hint),
            "attempts" to attempts.size,
        )
    }

    private fun sendSmsOnSubscription(
        normalized: String,
        body: String,
        subscriptionId: Int,
    ): Map<String, Any?> {
        val first = sendSmsOnSubscriptionOnce(normalized, body, subscriptionId)
        if (first["ok"] == true) return first
        val code = (first["resultCode"] as? Number)?.toInt() ?: -1
        if (!SmsSentWaiters.isTransientModemError(code)) return first
        // Modem often needs a short cool-down before the next SMS (esp. UCS-2 multiparts).
        try {
            Thread.sleep(900)
        } catch (_: InterruptedException) {
        }
        return sendSmsOnSubscriptionOnce(normalized, body, subscriptionId)
    }

    private fun sendSmsOnSubscriptionOnce(
        normalized: String,
        body: String,
        subscriptionId: Int,
    ): Map<String, Any?> {
        return try {
            val sms = smsManagerFor(subscriptionId)
            val code = requestCode.incrementAndGet()
            val parts = sms.divideMessage(body)
            val partCount = if (parts != null && parts.size > 1) parts.size else 1
            SmsSentWaiters.armSent(code, partCount)
            SmsSentWaiters.armDelivered(code)

            val sentIntents = ArrayList<PendingIntent>(partCount)
            val delIntents = ArrayList<PendingIntent>(partCount)
            repeat(partCount) { index ->
                val sentIntent = Intent(ACTION_SMS_SENT).apply {
                    setPackage(activity.packageName)
                    putExtra("address", normalized)
                    putExtra(SmsStatusReceiver.EXTRA_REQUEST_CODE, code)
                    putExtra("partIndex", index)
                }
                val delIntent = Intent(ACTION_SMS_DELIVERED).apply {
                    setPackage(activity.packageName)
                    putExtra("address", normalized)
                    putExtra(SmsStatusReceiver.EXTRA_REQUEST_CODE, code)
                    putExtra("partIndex", index)
                }
                sentIntents.add(
                    PendingIntent.getBroadcast(
                        activity,
                        code * 10 + index,
                        sentIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
                delIntents.add(
                    PendingIntent.getBroadcast(
                        activity,
                        code * 10 + index + 500_000,
                        delIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            }

            if (partCount > 1 && parts != null) {
                sms.sendMultipartTextMessage(normalized, null, parts, sentIntents, delIntents)
            } else {
                sms.sendTextMessage(normalized, null, body, sentIntents[0], delIntents[0])
            }

            val resultCode = SmsSentWaiters.awaitSent(code)
            if (resultCode != android.app.Activity.RESULT_OK) {
                return mapOf(
                    "ok" to false,
                    "status" to "failed",
                    "error" to SmsSentWaiters.sentErrorMessage(resultCode),
                    "address" to normalized,
                    "resultCode" to resultCode,
                    "subscriptionId" to subscriptionId,
                )
            }

            writeToSentBox(normalized, body)
            SmsEventHub.emit(
                mapOf(
                    "type" to "onSmsChanged",
                    "reason" to "sent",
                    "address" to normalized,
                    "body" to body,
                    "dateMs" to System.currentTimeMillis(),
                    "subscriptionId" to subscriptionId,
                ),
            )
            mapOf(
                "ok" to true,
                "status" to "sent",
                "address" to normalized,
                "subscriptionId" to subscriptionId,
                "error" to null,
            )
        } catch (e: Exception) {
            mapOf(
                "ok" to false,
                "status" to "failed",
                "error" to (e.message ?: "send failed"),
                "address" to normalized,
                "subscriptionId" to subscriptionId,
                "resultCode" to SmsManager.RESULT_ERROR_GENERIC_FAILURE,
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
        val cleaned = addresses.map { PhoneNormalizer.normalize(it) }.filter { it.isNotEmpty() }.distinct()
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
        var consecutiveFails = 0
        val results = mutableListOf<Map<String, Any?>>()

        for (index in cleaned.indices) {
            val address = cleaned[index]
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
                break
            }
            // Auto (-1): let sendSms pick last-OK SIM + failover.
            // Explicit SIM: use that slot only.
            // allSims: optional round-robin (legacy) — prefer Auto for load.
            val subId = when {
                subscriptionId >= 0 -> subscriptionId
                allSims && simIds.size > 1 -> simIds[index % simIds.size]
                else -> -1
            }
            val result = sendSms(address, body, subId).toMutableMap()
            result["index"] = index
            results.add(result)
            if (result["ok"] == true) {
                sent++
                consecutiveFails = 0
            } else {
                failed++
                consecutiveFails++
            }

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
            // Pace blasts so the modem can keep up (codes 16/124 = busy/overloaded).
            // PH prepaid modems often need 2s+ between recipients.
            val partHint = try {
                smsManagerFor(
                    (result["subscriptionId"] as? Number)?.toInt() ?: -1,
                ).divideMessage(body)?.size ?: 1
            } catch (_: Exception) {
                1
            }
            val delayMs = when {
                consecutiveFails >= 5 -> 8000L
                consecutiveFails >= 3 -> 4500L
                consecutiveFails >= 1 -> 3000L
                partHint > 3 -> 2800L
                partHint > 1 -> 2200L
                else -> 1800L
            }
            try {
                Thread.sleep(delayMs)
            } catch (_: InterruptedException) {
            }
            if (consecutiveFails >= 5 && consecutiveFails % 5 == 0) {
                // Cool-down so carrier/modem can recover from burst rejects.
                try {
                    Thread.sleep(10_000L)
                } catch (_: InterruptedException) {
                }
            }
        }

        if (cancelled) {
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
                put(Telephony.Sms.DATE_SENT, System.currentTimeMillis())
                put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_SENT)
                put(Telephony.Sms.READ, 1)
                put(Telephony.Sms.SEEN, 1)
            }
            activity.contentResolver.insert(Telephony.Sms.Sent.CONTENT_URI, values)
                ?: activity.contentResolver.insert(Uri.parse("content://sms/sent"), values)
        } catch (_: Exception) {
        }
    }

    companion object {
        private val requestCode = AtomicInteger(6000)
        private val cancelFlag = AtomicBoolean(false)
        const val PREFS = "callvault_sms"
        const val KEY_SCHEDULED = "scheduled_blasts"
        const val KEY_LAST_SMS_SUB = "last_successful_sms_sub"
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
