package com.callvault.prototype.sms

import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Telephony

/**
 * Watches the system SMS provider and notifies [SmsEventHub] when the inbox changes.
 */
class SmsContentObserver(
    private val context: Context,
    private val onChanged: (reason: String) -> Unit,
) : ContentObserver(Handler(Looper.getMainLooper())) {
    private var registered = false
    private var lastEmitMs = 0L

    fun start() {
        if (registered) return
        try {
            context.contentResolver.registerContentObserver(
                Telephony.Sms.CONTENT_URI,
                true,
                this,
            )
            registered = true
        } catch (_: Exception) {
        }
    }

    fun stop() {
        if (!registered) return
        try {
            context.contentResolver.unregisterContentObserver(this)
        } catch (_: Exception) {
        }
        registered = false
    }

    override fun onChange(selfChange: Boolean) {
        onChange(selfChange, null)
    }

    override fun onChange(selfChange: Boolean, uri: Uri?) {
        val now = System.currentTimeMillis()
        if (now - lastEmitMs < 400) return
        lastEmitMs = now
        onChanged("provider")
    }
}
