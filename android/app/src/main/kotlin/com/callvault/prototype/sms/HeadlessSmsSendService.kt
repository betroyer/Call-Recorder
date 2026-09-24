package com.callvault.prototype.sms

import android.app.Service
import android.content.Intent
import android.os.IBinder

/**
 * Quick-reply / respond-via-message service required for default SMS role.
 */
class HeadlessSmsSendService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "android.intent.action.RESPOND_VIA_MESSAGE") {
            val uri = intent.data
            val address = uri?.schemeSpecificPart?.removePrefix("//")
                ?: uri?.path?.trimStart('/')
                ?: ""
            val body = intent.getStringExtra(Intent.EXTRA_TEXT).orEmpty()
            if (address.isNotBlank() && body.isNotBlank()) {
                SmsHelperApp(applicationContext).sendSms(address, body)
            }
        }
        stopSelf(startId)
        return START_NOT_STICKY
    }
}
