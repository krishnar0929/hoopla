package com.northbitapps.hoopla

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Links shared to Hoopla (Instagram → Share → Hoopla) waiting for the Flutter app.
    private val pending = mutableListOf<Map<String, String>>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hoopla/share").setMethodCallHandler { call, result ->
            if (call.method == "takeSharedReels") {
                val items = ArrayList(pending)
                pending.clear()
                result.success(items)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        keepShared(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        keepShared(intent)
    }

    private fun keepShared(intent: Intent?) {
        if (intent == null || intent.action != Intent.ACTION_SEND) return
        if (intent.type?.startsWith("text/") != true) return
        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return
        val url = Regex("https?://\\S+").find(text)?.value ?: return
        pending.add(mapOf("url" to url, "title" to ""))
        // Handled once; don't save it again after a rotation.
        intent.action = Intent.ACTION_MAIN
    }
}
