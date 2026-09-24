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
import com.callvault.prototype.telecom.CallStateMonitor
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

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

    fun register() {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        RecordingService.addListener(this)
    }

    fun dispose() {
        callMonitor?.stop()
        callMonitor = null
        RecordingService.removeListener(this)
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
                // Caller should re-check after the system dialog.
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
            else -> result.notImplemented()
        }
    }

    private fun startRecording(result: MethodChannel.Result) {
        if (!hasPermission(Manifest.permission.RECORD_AUDIO)) {
            result.error("permission_required", "RECORD_AUDIO required", null)
            return
        }
        if (Build.VERSION.SDK_INT >= 33 && !hasPermission(Manifest.permission.POST_NOTIFICATIONS)) {
            // Soft warning — still attempt; FGS notification may be limited.
            emit(
                mapOf(
                    "type" to "onRecordingState",
                    "state" to "warning",
                    "error" to "POST_NOTIFICATIONS not granted; notification may be hidden",
                ),
            )
        }

        pendingStartResult = { start ->
            activity.runOnUiThread {
                if (start.started) {
                    result.success(
                        mapOf(
                            "recordingStarted" to true,
                            "path" to start.path,
                            "recordingSourceTried" to start.source,
                            "error" to null,
                        ),
                    )
                } else {
                    result.success(
                        mapOf(
                            "recordingStarted" to false,
                            "path" to null,
                            "recordingSourceTried" to start.source,
                            "error" to start.error,
                        ),
                    )
                }
            }
            pendingStartResult = null
        }
        RecordingService.start(activity)
    }

    private fun stopRecording(result: MethodChannel.Result) {
        pendingStopResult = { stop ->
            activity.runOnUiThread {
                result.success(
                    mapOf(
                        "path" to stop.path,
                        "durationMs" to stop.durationMs,
                        "bytes" to stop.bytes,
                        "recordingSourceTried" to stop.source,
                        "error" to stop.error,
                    ),
                )
            }
            pendingStopResult = null
        }
        if (!RecordingService.isRunning && pendingStopResult != null) {
            // Service not running — still try to answer with empty stop.
            val empty = CallRecorder.StopResult(null, 0, 0, null, "Service not running")
            pendingStopResult?.invoke(empty)
            pendingStopResult = null
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
            // Map offhook as "connected" for prototype UI clarity.
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

    private fun emit(payload: Map<String, Any?>) {
        activity.runOnUiThread {
            eventSink?.success(payload)
        }
    }

    private fun permissionMap(): Map<String, Boolean> {
        val map = mutableMapOf(
            "microphone" to hasPermission(Manifest.permission.RECORD_AUDIO),
            "phone" to hasPermission(Manifest.permission.READ_PHONE_STATE),
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
        )
        if (Build.VERSION.SDK_INT >= 33) {
            list.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        return list.toTypedArray()
    }

    private fun hasPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(activity, permission) ==
            PackageManager.PERMISSION_GRANTED
    }

    companion object {
        const val METHOD_CHANNEL = "com.callvault.prototype/bridge"
        const val EVENT_CHANNEL = "com.callvault.prototype/events"
        private const val REQ_PERMS = 4201
    }
}
