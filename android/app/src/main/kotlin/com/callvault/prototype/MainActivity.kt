package com.callvault.prototype

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.callvault.prototype.bridge.CallVaultBridge

class MainActivity : FlutterActivity() {
    private var bridge: CallVaultBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridge = CallVaultBridge(this, flutterEngine)
        bridge?.register()
    }

    override fun onDestroy() {
        bridge?.dispose()
        bridge = null
        super.onDestroy()
    }
}
