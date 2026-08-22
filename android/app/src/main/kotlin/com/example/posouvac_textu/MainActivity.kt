package com.example.posouvac_textu

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var concertMode = false
    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "concert_volume_channel")
        channel.setMethodCallHandler { call, result ->
            if (call.method == "setConcertMode") {
                concertMode = call.argument<Boolean>("enabled") == true
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (concertMode && event.action == KeyEvent.ACTION_DOWN &&
            (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP || event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)
        ) {
            val delta = if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) 5 else -5
            val effective = if (event.repeatCount > 0 || event.isLongPress) delta * 2 else delta
            // Poslat do Flutteru - BPM změna. Nečekáme na výsledek.
            try {
                channel.invokeMethod("onVolumeBpm", mapOf("delta" to effective))
            } catch (_: Exception) {
            }
            return true // potlačí systémovou hlasitost
        }
        return super.dispatchKeyEvent(event)
    }
}
