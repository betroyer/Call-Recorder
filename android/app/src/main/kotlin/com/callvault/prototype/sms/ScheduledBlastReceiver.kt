package com.callvault.prototype.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.Toast

/**
 * Fires scheduled SMS blasts via AlarmManager.
 */
class ScheduledBlastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != SmsHelper.ACTION_SCHEDULED_BLAST) return
        val jobId = intent.getStringExtra("jobId") ?: return
        val job = SmsHelper.takeScheduledJob(context, jobId) ?: return

        val addresses = mutableListOf<String>()
        val arr = job.getJSONArray("addresses")
        for (i in 0 until arr.length()) addresses.add(arr.getString(i))
        val body = job.getString("body")
        val subscriptionId = job.optInt("subscriptionId", -1)
        val allSims = job.optBoolean("allSims", false)

        // PendingResult so we can do work off the main thread briefly.
        val pending = goAsync()
        Thread {
            try {
                // Need an Activity for SmsHelper historically — use application context path.
                val helper = SmsHelperApp(context.applicationContext)
                val result = helper.sendBlast(
                    addresses = addresses,
                    body = body,
                    subscriptionId = subscriptionId,
                    allSims = allSims,
                    blastId = jobId,
                )
                Log.i(TAG, "Scheduled blast $jobId sent=${result["sent"]} failed=${result["failed"]}")
            } catch (e: Exception) {
                Log.e(TAG, "Scheduled blast failed", e)
            } finally {
                pending.finish()
            }
        }.start()

        try {
            Toast.makeText(context, "CallVault: scheduled SMS blast started", Toast.LENGTH_SHORT).show()
        } catch (_: Exception) {
        }
    }

    companion object {
        private const val TAG = "ScheduledBlastRx"
    }
}
