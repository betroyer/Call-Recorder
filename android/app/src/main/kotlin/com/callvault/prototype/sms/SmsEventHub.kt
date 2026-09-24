package com.callvault.prototype.sms

/**
 * Bridges BroadcastReceivers → Flutter EventChannel while the activity is alive.
 */
object SmsEventHub {
    @Volatile
    var listener: ((Map<String, Any?>) -> Unit)? = null

    fun emit(payload: Map<String, Any?>) {
        listener?.invoke(payload)
    }
}
