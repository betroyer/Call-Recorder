package com.callvault.prototype.telecom

import android.content.Context
import android.os.Build
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import androidx.annotation.RequiresApi

/**
 * Observes cellular call state via TelephonyCallback (API 31+) or PhoneStateListener (API 29–30).
 * Does not grant call-audio access — state only.
 */
class CallStateMonitor(
    private val context: Context,
    private val onStateChanged: (state: String, number: String?) -> Unit,
) {
    private val telephony =
        context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

    private var telephonyCallback: TelephonyCallback? = null
    private var phoneStateListener: PhoneStateListener? = null
    private var listening = false

    fun start() {
        if (listening) return
        listening = true

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            startModern()
        } else {
            startLegacy()
        }
    }

    fun stop() {
        if (!listening) return
        listening = false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            telephonyCallback?.let {
                telephony.unregisterTelephonyCallback(it)
            }
            telephonyCallback = null
        } else {
            @Suppress("DEPRECATION")
            phoneStateListener?.let {
                telephony.listen(it, PhoneStateListener.LISTEN_NONE)
            }
            phoneStateListener = null
        }
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun startModern() {
        val callback = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
            override fun onCallStateChanged(state: Int) {
                emit(state, null)
            }
        }
        telephonyCallback = callback
        telephony.registerTelephonyCallback(context.mainExecutor, callback)
        emit(telephony.callState, null)
    }

    @Suppress("DEPRECATION")
    private fun startLegacy() {
        val listener = object : PhoneStateListener() {
            @Deprecated("Deprecated in Java")
            override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                emit(state, phoneNumber)
            }
        }
        phoneStateListener = listener
        telephony.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
        emit(telephony.callState, null)
    }

    private fun emit(state: Int, number: String?) {
        val mapped = when (state) {
            TelephonyManager.CALL_STATE_IDLE -> "idle"
            TelephonyManager.CALL_STATE_RINGING -> "ringing"
            TelephonyManager.CALL_STATE_OFFHOOK -> "offhook"
            else -> "unknown"
        }
        onStateChanged(mapped, number?.takeIf { it.isNotBlank() })
    }
}
