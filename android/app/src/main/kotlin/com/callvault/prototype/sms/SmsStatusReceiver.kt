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

/**
 * Captures SmsManager sent/delivered PendingIntent results.
 */
class SmsStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        val requestCode = intent.getIntExtra(EXTRA_REQUEST_CODE, -1)
        if (requestCode < 0) return
        when (action) {
            SmsHelper.ACTION_SMS_SENT -> Waiters.completeSent(requestCode, resultCode)
            SmsHelper.ACTION_SMS_DELIVERED -> Waiters.completeDelivered(requestCode, resultCode)
        }
    }

    companion object {
        const val EXTRA_REQUEST_CODE = "requestCode"

        object Waiters {
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

            /** Blocks until all parts report (or timeout). Returns worst result code. */
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
                else -> "Send failed (code $resultCode). Check SIM credit and signal."
            }
        }
    }
}
