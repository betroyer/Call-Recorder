package com.callvault.prototype.sms

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsManager
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/** Holds in-flight SMS sent/delivered waiters (shared with [SmsStatusReceiver]). */
object SmsSentWaiters {
    private data class SentWait(
        val worstCode: AtomicInteger = AtomicInteger(Activity.RESULT_OK),
        val latch: CountDownLatch,
    )

    private val sent = ConcurrentHashMap<Int, SentWait>()
    private val delivered = ConcurrentHashMap<Int, AtomicInteger>()

    fun armSent(requestCode: Int, parts: Int = 1) {
        sent[requestCode] = SentWait(latch = CountDownLatch(parts.coerceAtLeast(1)))
    }

    fun completeSent(requestCode: Int, resultCode: Int) {
        val entry = sent[requestCode] ?: return
        if (resultCode != Activity.RESULT_OK) {
            entry.worstCode.set(resultCode)
        }
        entry.latch.countDown()
    }

    fun awaitSent(requestCode: Int, timeoutMs: Long = 25_000L): Int {
        val entry = sent[requestCode] ?: return Activity.RESULT_OK
        val finished = entry.latch.await(timeoutMs, TimeUnit.MILLISECONDS)
        sent.remove(requestCode)
        if (!finished) {
            return SmsManager.RESULT_ERROR_GENERIC_FAILURE
        }
        return entry.worstCode.get()
    }

    fun armDelivered(requestCode: Int) {
        delivered[requestCode] = AtomicInteger(-1)
    }

    fun completeDelivered(requestCode: Int, resultCode: Int) {
        delivered[requestCode]?.set(resultCode)
    }

    fun sentErrorMessage(resultCode: Int): String = when (resultCode) {
        Activity.RESULT_OK -> "ok"
        SmsManager.RESULT_ERROR_GENERIC_FAILURE ->
            "Send failed (generic). Check load/credit, signal, and SIM."
        SmsManager.RESULT_ERROR_NO_SERVICE ->
            "No cellular service — SMS cannot send right now."
        SmsManager.RESULT_ERROR_NULL_PDU ->
            "Send failed (null PDU)."
        SmsManager.RESULT_ERROR_RADIO_OFF ->
            "Radio/airplane mode is off — turn on mobile network."
        SmsManager.RESULT_ERROR_LIMIT_EXCEEDED ->
            "Too many SMS queued — wait a moment and try again."
        SmsManager.RESULT_ERROR_FDN_CHECK_FAILURE ->
            "Blocked by Fixed Dialing Numbers (FDN) on this SIM."
        // RESULT_MODEM_ERROR = 16 (API 30+)
        16 ->
            "Modem error (code 16). Pick the SIM with load under Send via, " +
                "toggle Airplane mode, end any call, then retry. " +
                "Set PYX Food Products as the default SMS app."
        // RESULT_NETWORK_ERROR = 17
        17 ->
            "Network rejected the SMS (code 17). Check signal and try again."
        // RESULT_INVALID_SMSC_ADDRESS = 19
        19 ->
            "Invalid SMS center (SMSC) on this SIM — contact your carrier."
        // RESULT_NO_DEFAULT_SMS_APP
        32 ->
            "No default SMS app — set PYX Food Products as the default SMS app."
        // Common OEM RIL busy / send-fail-retry (seen as 124 on many PH devices)
        124, 111, 105 ->
            "Modem busy (code $resultCode). The radio is overloaded or the wrong SIM " +
                "has no load. Wait a few seconds, choose the SIM with load (or Auto), " +
                "set PYX Food Products as default SMS, then retry. Large blasts are paced slower now."
        else ->
            "Send failed (code $resultCode). Check SIM load, signal, correct SIM slot, " +
                "and set PYX Food Products as the default SMS app."
    }

    fun isTransientModemError(resultCode: Int): Boolean =
        resultCode == 16 ||
            resultCode == 17 ||
            resultCode == SmsManager.RESULT_ERROR_GENERIC_FAILURE ||
            resultCode == SmsManager.RESULT_ERROR_LIMIT_EXCEEDED ||
            resultCode in 100..130
}

/**
 * Captures SmsManager sent/delivered PendingIntent results.
 */
class SmsStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        val requestCode = intent.getIntExtra(EXTRA_REQUEST_CODE, -1)
        if (requestCode < 0) return
        when (action) {
            SmsHelper.ACTION_SMS_SENT -> SmsSentWaiters.completeSent(requestCode, resultCode)
            SmsHelper.ACTION_SMS_DELIVERED -> SmsSentWaiters.completeDelivered(requestCode, resultCode)
        }
    }

    companion object {
        const val EXTRA_REQUEST_CODE = "requestCode"
    }
}
