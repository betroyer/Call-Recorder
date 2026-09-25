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

/** Outcome of an SMS sent PendingIntent (result code + OEM extras). */
data class SmsSentOutcome(
    val resultCode: Int,
    val noDefault: Boolean = false,
    val errorCode: Int = -1,
    val timedOut: Boolean = false,
)

/** Holds in-flight SMS sent/delivered waiters (shared with [SmsStatusReceiver]). */
object SmsSentWaiters {
    private data class SentWait(
        val worstCode: AtomicInteger = AtomicInteger(Activity.RESULT_OK),
        val noDefault: AtomicInteger = AtomicInteger(0),
        val errorCode: AtomicInteger = AtomicInteger(-1),
        val latch: CountDownLatch,
    )

    private val sent = ConcurrentHashMap<Int, SentWait>()
    private val delivered = ConcurrentHashMap<Int, AtomicInteger>()

    fun armSent(requestCode: Int, parts: Int = 1) {
        sent[requestCode] = SentWait(latch = CountDownLatch(parts.coerceAtLeast(1)))
    }

    fun completeSent(
        requestCode: Int,
        resultCode: Int,
        noDefault: Boolean = false,
        errorCode: Int = -1,
    ) {
        val entry = sent[requestCode] ?: return
        if (resultCode != Activity.RESULT_OK) {
            entry.worstCode.set(resultCode)
        }
        if (noDefault) entry.noDefault.set(1)
        if (errorCode >= 0) entry.errorCode.set(errorCode)
        entry.latch.countDown()
    }

    fun awaitSent(requestCode: Int, timeoutMs: Long = 45_000L): SmsSentOutcome {
        val entry = sent[requestCode]
        if (entry == null) {
            return SmsSentOutcome(Activity.RESULT_OK)
        }
        val finished = entry.latch.await(timeoutMs, TimeUnit.MILLISECONDS)
        sent.remove(requestCode)
        if (!finished) {
            return SmsSentOutcome(
                resultCode = SmsManager.RESULT_ERROR_GENERIC_FAILURE,
                timedOut = true,
            )
        }
        return SmsSentOutcome(
            resultCode = entry.worstCode.get(),
            noDefault = entry.noDefault.get() == 1,
            errorCode = entry.errorCode.get(),
        )
    }

    fun armDelivered(requestCode: Int) {
        delivered[requestCode] = AtomicInteger(-1)
    }

    fun completeDelivered(requestCode: Int, resultCode: Int) {
        delivered[requestCode]?.set(resultCode)
    }

    fun sentErrorMessage(outcome: SmsSentOutcome): String {
        if (outcome.timedOut) {
            return "No send status from the modem (timeout). Common on Realme — " +
                "set battery Unrestricted, keep screen on, confirm Globe SMS load, retry."
        }
        if (outcome.noDefault) {
            return "No preferred SIM for SMS (Ask every time). " +
                "Open Settings → Dual SIM & Mobile network → Preferred SIM for SMS → " +
                "pick the SIM with load (not Ask every time). Common on Realme/Oppo."
        }
        val resultCode = outcome.resultCode
        val ril = if (outcome.errorCode >= 0) " (radio ${outcome.errorCode})" else ""
        return when (resultCode) {
            Activity.RESULT_OK -> "ok"
            SmsManager.RESULT_ERROR_GENERIC_FAILURE ->
                "Send failed (generic)$ril. Check Globe SMS load, signal, " +
                    "battery Unrestricted, and PYX as default SMS."
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
            16 ->
                "Modem error (code 16)$ril. Toggle Airplane mode, confirm Globe SMS load, " +
                    "battery Unrestricted, then retry."
            17 ->
                "Network rejected the SMS (code 17)$ril. Check signal and try again."
            19 ->
                "Invalid SMS center (SMSC) on this SIM — contact Globe."
            32 ->
                "No default SMS app — set PYX Food Products as the default SMS app."
            124, 111, 105 ->
                "Modem busy (code $resultCode)$ril. Usually no Globe SMS load/promo, " +
                    "or the radio needs a cool-down. Open the stock Messages app and send " +
                    "the same number — if that also fails, buy/register a Globe SMS promo " +
                    "(*143#), toggle Airplane mode 10s, then retry here."
            else ->
                "Send failed (code $resultCode)$ril. Check Globe load, signal, " +
                    "battery Unrestricted, and PYX as default SMS."
        }
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
        val noDefault = intent.getBooleanExtra("noDefault", false)
        val errorCode = intent.getIntExtra("errorCode", -1)
        when (action) {
            SmsHelper.ACTION_SMS_SENT ->
                SmsSentWaiters.completeSent(requestCode, resultCode, noDefault, errorCode)
            SmsHelper.ACTION_SMS_DELIVERED ->
                SmsSentWaiters.completeDelivered(requestCode, resultCode)
        }
    }

    companion object {
        const val EXTRA_REQUEST_CODE = "requestCode"
    }
}
