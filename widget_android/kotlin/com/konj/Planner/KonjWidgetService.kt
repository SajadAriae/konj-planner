package com.konj.planner

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.provider.Settings
import android.util.Base64
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPick: MethodChannel.Result? = null

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
                "pickFile" -> {
                    pendingPick = result
                    val pi = Intent(Intent.ACTION_GET_CONTENT)
                    pi.type = "*/*"
                    pi.addCategory(Intent.CATEGORY_OPENABLE)
                    startActivityForResult(Intent.createChooser(pi, null), 4711)
                }
                "shareText" -> {
                    try {
                        val i = Intent(Intent.ACTION_SEND)
                        i.type = "text/plain"
                        i.putExtra(Intent.EXTRA_TEXT, call.arguments as String)
                        val c = Intent.createChooser(i, null)
                        c.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(c)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "openUrl" -> {
                    try {
                        val i = Intent(Intent.ACTION_VIEW, Uri.parse(call.arguments as String))
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(i)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "keepOn" -> {
                    val on = call.arguments as? Boolean ?: false
                    runOnUiThread {
                        if (on) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == 4711) {
            val res = pendingPick
            pendingPick = null
            if (res == null) return
            val uri = data?.data
            if (resultCode != RESULT_OK || uri == null) {
                res.success(null)
                return
            }
            try {
                var name = "file"
                var size = 0L
                contentResolver.query(uri, null, null, null, null)?.use { c ->
                    if (c.moveToFirst()) {
                        val ni = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (ni >= 0) name = c.getString(ni)
                        val si = c.getColumnIndex(OpenableColumns.SIZE)
                        if (si >= 0) size = c.getLong(si)
                    }
                }
                if (size > 5L * 1024 * 1024) {
                    res.success(mapOf("error" to "big"))
                    return
                }
                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: ByteArray(0)
                if (bytes.size > 5 * 1024 * 1024) {
                    res.success(mapOf("error" to "big"))
                    return
                }
                val mime = contentResolver.getType(uri) ?: "application/octet-stream"
                res.success(mapOf("name" to name, "mime" to mime, "b64" to Base64.encodeToString(bytes, Base64.NO_WRAP)))
            } catch (e: Exception) {
                res.success(null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
