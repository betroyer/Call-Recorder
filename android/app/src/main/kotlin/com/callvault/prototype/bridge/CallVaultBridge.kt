package com.callvault.prototype.bridge

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.callvault.prototype.recorder.CallRecorder
import com.callvault.prototype.recorder.RecordingService
import com.callvault.prototype.shizuku.ShizukuRecorderClient
import com.callvault.prototype.sms.SmsContentObserver
import com.callvault.prototype.sms.SmsEventHub
import com.callvault.prototype.sms.SmsHelper
import com.callvault.prototype.sms.SmsNotificationHelper
import com.callvault.prototype.telecom.CallStateMonitor
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku

class CallVaultBridge(
    private val activity: Activity,
    flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    RecordingService.Listener {

    private val methodChannel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        METHOD_CHANNEL,
    )
    private val eventChannel = EventChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        EVENT_CHANNEL,
    )

    private var eventSink: EventChannel.EventSink? = null
    private var callMonitor: CallStateMonitor? = null
    private var lastCallState: String = "idle"
    private var pendingStartResult: ((CallRecorder.StartResult) -> Unit)? = null
    private var pendingStopResult: ((CallRecorder.StopResult) -> Unit)? = null
    private var useShizuku: Boolean = false
    private var activeMode: String = "none" // none | normal | shizuku
    private val shizukuClient by lazy { ShizukuRecorderClient(activity) }
    private val smsHelper by lazy { SmsHelper(activity) }
    private var smsObserver: SmsContentObserver? = null

    private val shizukuPermissionListener =
        Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
            if (requestCode == ShizukuRecorderClient.REQ_CODE) {
                emit(
                    mapOf(
                        "type" to "onShizukuState",
                        "granted" to (grantResult == PackageManager.PERMISSION_GRANTED),
                        "status" to shizukuClient.status(),
                    ),
                )
            }
        }

    fun register() {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        RecordingService.addListener(this)
        SmsNotificationHelper.ensureChannel(activity)
        SmsEventHub.listener = { payload -> emit(payload) }
        smsObserver = SmsContentObserver(activity) {
            emit(
                mapOf(
                    "type" to "onSmsChanged",
                    "reason" to it,
                ),
            )
        }.also { it.start() }
        try {
            Shizuku.addRequestPermissionResultListener(shizukuPermissionListener)
        } catch (_: Exception) {
        }
    }

    fun dispose() {
        callMonitor?.stop()
        callMonitor = null
        smsObserver?.stop()
        smsObserver = null
        SmsEventHub.listener = null
        RecordingService.removeListener(this)
        try {
            Shizuku.removeRequestPermissionResultListener(shizukuPermissionListener)
        } catch (_: Exception) {
        }
        if (activeMode == "shizuku") {
            try {
                shizukuClient.stop()
            } catch (_: Exception) {
            }
            activeMode = "none"
        }
        shizukuClient.unbind()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ping" -> result.success(
                mapOf(
                    "ok" to true,
                    "platform" to "android",
                    "sdkInt" to Build.VERSION.SDK_INT,
                ),
            )
            "checkPermissions" -> result.success(permissionMap())
            "requestPermissions" -> {
                ActivityCompat.requestPermissions(activity, requiredPermissions(), REQ_PERMS)
                result.success(mapOf("requested" to true))
            }
            "openAppSettings" -> {
                val intent = Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", activity.packageName, null),
                )
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(intent)
                result.success(true)
            }
            "getShizukuStatus" -> result.success(shizukuClient.status())
            "requestShizukuPermission" -> {
                val ok = shizukuClient.requestPermission()
                result.success(mapOf("requested" to ok, "status" to shizukuClient.status()))
            }
            "openShizukuApp" -> result.success(openShizukuApp())
            "setUseShizuku" -> {
                useShizuku = call.argument<Boolean>("enabled") == true
                result.success(mapOf("useShizuku" to useShizuku))
            }
            "getUseShizuku" -> result.success(mapOf("useShizuku" to useShizuku))
            "startCallMonitor" -> {
                if (!hasPermission(Manifest.permission.READ_PHONE_STATE)) {
                    result.error("permission_required", "READ_PHONE_STATE required", null)
                    return
                }
                ensureMonitor().start()
                result.success(mapOf("monitoring" to true, "state" to lastCallState))
            }
            "stopCallMonitor" -> {
                callMonitor?.stop()
                result.success(mapOf("monitoring" to false))
            }
            "startRecording" -> startRecording(result)
            "stopRecording" -> stopRecording(result)
            "getLastRecordingPath" -> result.success(CallRecorder.lastRecordingPath(activity))
            "listRecordings" -> result.success(CallRecorder.listRecordings(activity))
            "listSmsInbox" -> {
                val limit = call.argument<Int>("limit") ?: 100
                result.success(smsHelper.listInbox(limit))
            }
            "setSmsRead" -> {
                val id = call.argument<Number>("id")?.toLong()
                val read = call.argument<Boolean>("read") != false
                if (id == null) {
                    result.error("invalid", "id required", null)
                    return
                }
                result.success(smsHelper.setMessageRead(id, read))
            }
            "setSmsThreadRead" -> {
                val address = call.argument<String>("address") ?: ""
                val read = call.argument<Boolean>("read") != false
                result.success(smsHelper.setThreadRead(address, read))
            }
            "listSmsConversations" -> {
                val limit = call.argument<Int>("limit") ?: 80
                result.success(smsHelper.listConversations(limit))
            }
            "listSmsThread" -> {
                val address = call.argument<String>("address") ?: ""
                val limit = call.argument<Int>("limit") ?: 200
                result.success(smsHelper.threadMessages(address, limit))
            }
            "listSims" -> result.success(smsHelper.listSims())
            "listContacts" -> {
                val limit = call.argument<Int>("limit") ?: 500
                result.success(smsHelper.listContacts(limit))
            }
            "isDefaultSmsApp" -> result.success(mapOf("isDefault" to smsHelper.isDefaultSmsApp()))
            "requestDefaultSmsRole" -> result.success(mapOf("requested" to smsHelper.requestDefaultSmsRole()))
            "openMmsComposer" -> {
                val addresses = call.argument<List<String>>("addresses") ?: emptyList()
                val body = call.argument<String>("body") ?: ""
                result.success(mapOf("ok" to smsHelper.openMmsComposer(addresses, body)))
            }
            "sendSms" -> {
                val address = call.argument<String>("address") ?: ""
                val body = call.argument<String>("body") ?: ""
                val subscriptionId = call.argument<Int>("subscriptionId") ?: -1
                Thread {
                    val payload = smsHelper.sendSms(address, body, subscriptionId)
                    activity.runOnUiThread { result.success(payload) }
                }.start()
            }
            "sendSmsBlast" -> {
                val addresses = call.argument<List<String>>("addresses") ?: emptyList()
                val body = call.argument<String>("body") ?: ""
                val subscriptionId = call.argument<Int>("subscriptionId") ?: -1
                val allSims = call.argument<Boolean>("allSims") == true
                val blastId = call.argument<String>("blastId")
                Thread {
                    val payload = smsHelper.sendBlast(
                        addresses = addresses,
                        body = body,
                        subscriptionId = subscriptionId,
                        allSims = allSims,
                        blastId = blastId,
                        onProgress = { p -> emit(p) },
                    )
                    activity.runOnUiThread { result.success(payload) }
                }.start()
            }
            "cancelSmsBlast" -> {
                smsHelper.cancelBlast()
                result.success(mapOf("ok" to true))
            }
            "scheduleSmsBlast" -> {
                val addresses = call.argument<List<String>>("addresses") ?: emptyList()
                val body = call.argument<String>("body") ?: ""
                val triggerAtMs = (call.argument<Number>("triggerAtMs")?.toLong()) ?: 0L
                val subscriptionId = call.argument<Int>("subscriptionId") ?: -1
                val allSims = call.argument<Boolean>("allSims") == true
                val priority = call.argument<String>("priority") ?: "Low"
                result.success(
                    smsHelper.scheduleBlast(
                        addresses,
                        body,
                        triggerAtMs,
                        subscriptionId,
                        allSims,
                        priority,
                    ),
                )
            }
            "listScheduledBlasts" -> result.success(smsHelper.listScheduledBlasts())
            else -> result.notImplemented()
        }
    }

    private fun startRecording(result: MethodChannel.Result) {
        if (!hasPermission(Manifest.permission.RECORD_AUDIO)) {
            result.error("permission_required", "RECORD_AUDIO required", null)
            return
        }

        if (useShizuku) {
            startShizukuRecording(result)
            return
        }

        activeMode = "normal"
        pendingStartResult = { start ->
            activity.runOnUiThread {
                result.success(start.toMap())
            }
            pendingStartResult = null
        }
        RecordingService.start(activity)
    }

    private fun startShizukuRecording(result: MethodChannel.Result) {
        Thread {
            RecordingService.startNotifyOnly(activity)
            val start = shizukuClient.start()
            activeMode = if (start.started) "shizuku" else "none"
            if (!start.started) {
                RecordingService.stop(activity)
            }
            activity.runOnUiThread {
                result.success(start.toMap())
                emit(
                    mapOf(
                        "type" to "onRecordingState",
                        "state" to if (start.started) "recording" else "failed",
                        "path" to start.path,
                        "source" to (start.source ?: if (start.started) "unknown" else null),
                        "error" to start.error,
                    ),
                )
            }
        }.start()
    }

    private fun stopRecording(result: MethodChannel.Result) {
        if (activeMode == "shizuku") {
            Thread {
                val stop = shizukuClient.stop()
                activeMode = "none"
                RecordingService.stop(activity)
                activity.runOnUiThread {
                    result.success(stop.toMap())
                    emit(
                        mapOf(
                            "type" to "onRecordingState",
                            "state" to if (stop.error == null) "stopped" else "failed",
                            "path" to stop.path,
                            "durationMs" to stop.durationMs,
                            "bytes" to stop.bytes,
                            "source" to stop.source,
                            "error" to stop.error,
                        ),
                    )
                }
            }.start()
            return
        }

        pendingStopResult = { stop ->
            activity.runOnUiThread {
                result.success(stop.toMap())
            }
            pendingStopResult = null
            activeMode = "none"
        }
        if (!RecordingService.isRunning) {
            val empty = CallRecorder.StopResult(null, 0, 0, null, "Service not running")
            pendingStopResult?.invoke(empty)
            pendingStopResult = null
            activeMode = "none"
            return
        }
        RecordingService.stop(activity)
    }

    override fun onRecordingStarted(result: CallRecorder.StartResult) {
        pendingStartResult?.invoke(result)
        emit(
            mapOf(
                "type" to "onRecordingState",
                "state" to if (result.started) "recording" else "failed",
                "path" to result.path,
                "source" to result.source,
                "error" to result.error,
            ),
        )
    }

    override fun onRecordingStopped(result: CallRecorder.StopResult) {
        pendingStopResult?.invoke(result)
        emit(
            mapOf(
                "type" to "onRecordingState",
                "state" to if (result.error == null) "stopped" else "failed",
                "path" to result.path,
                "durationMs" to result.durationMs,
                "bytes" to result.bytes,
                "source" to result.source,
                "error" to result.error,
            ),
        )
    }

    private fun ensureMonitor(): CallStateMonitor {
        val existing = callMonitor
        if (existing != null) return existing
        val monitor = CallStateMonitor(activity) { state, number ->
            lastCallState = state
            val uiState = if (state == "offhook") "connected" else state
            emit(
                mapOf(
                    "type" to "onCallState",
                    "state" to uiState,
                    "rawState" to state,
                    "number" to number,
                ),
            )
        }
        callMonitor = monitor
        return monitor
    }

    private fun openShizukuApp(): Boolean {
        val packages = listOf("moe.shizuku.privileged.api", "moe.shizuku.manager")
        for (pkg in packages) {
            val launch = activity.packageManager.getLaunchIntentForPackage(pkg)
            if (launch != null) {
                activity.startActivity(launch)
                return true
            }
        }
        return false
    }

    private fun emit(payload: Map<String, Any?>) {
        activity.runOnUiThread {
            eventSink?.success(payload)
        }
    }

    private fun permissionMap(): Map<String, Boolean> {
        val map = mutableMapOf(
            "microphone" to hasPermission(Manifest.permission.RECORD_AUDIO),
            "phone" to hasPermission(Manifest.permission.READ_PHONE_STATE),
            "smsSend" to hasPermission(Manifest.permission.SEND_SMS),
            "smsRead" to hasPermission(Manifest.permission.READ_SMS),
            "contacts" to hasPermission(Manifest.permission.READ_CONTACTS),
            "defaultSms" to smsHelper.isDefaultSmsApp(),
        )
        if (Build.VERSION.SDK_INT >= 33) {
            map["notifications"] = hasPermission(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            map["notifications"] = true
        }
        return map
    }

    private fun requiredPermissions(): Array<String> {
        val list = mutableListOf(
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.READ_PHONE_STATE,
            Manifest.permission.SEND_SMS,
            Manifest.permission.READ_SMS,
            Manifest.permission.RECEIVE_SMS,
            Manifest.permission.READ_CONTACTS,
        )
        if (Build.VERSION.SDK_INT >= 33) {
            list.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            list.add(Manifest.permission.SCHEDULE_EXACT_ALARM)
        }
        return list.toTypedArray()
    }

    private fun hasPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(activity, permission) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun CallRecorder.StartResult.toMap(): Map<String, Any?> = mapOf(
        "recordingStarted" to started,
        "path" to path,
        "recordingSourceTried" to (source ?: if (started) "unknown" else null),
        "error" to error,
    )

    private fun CallRecorder.StopResult.toMap(): Map<String, Any?> = mapOf(
        "path" to path,
        "durationMs" to durationMs,
        "bytes" to bytes,
        "recordingSourceTried" to (source ?: "unknown"),
        "error" to error,
    )

    companion object {
        const val METHOD_CHANNEL = "com.callvault.prototype/bridge"
        const val EVENT_CHANNEL = "com.callvault.prototype/events"
        private const val REQ_PERMS = 4201
    }
}
