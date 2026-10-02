package com.konj.planner

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "konj/shake").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val i = Intent(this, ShakeService::class.java)
                    if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
                    result.success(true)
                }
                "stop" -> {
                    stopService(Intent(this, ShakeService::class.java))
                    result.success(true)
                }
                "hasOverlay" -> result.success(Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(this))
                "openOverlay" -> {
                    startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
