package com.konj.planner

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import kotlin.math.sqrt

class ShakeService : Service(), SensorEventListener {
    private var lastShake = 0L
    private var firstShake = 0L
    private var count = 0
    private var lastOpen = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(NotificationChannel("konj_shake", "\u062A\u06A9\u0627\u0646 \u062F\u0627\u062F\u0646 \u0628\u0631\u0627\u06CC \u0628\u0627\u0632 \u06A9\u0631\u062F\u0646", NotificationManager.IMPORTANCE_LOW))
            nm.createNotificationChannel(NotificationChannel("konj_shake_open", "\u0628\u0627\u0632 \u06A9\u0631\u062F\u0646 Konj Planner", NotificationManager.IMPORTANCE_HIGH))
        }
        val n = buildNotification("konj_shake", "Konj Planner \u0622\u0645\u0627\u062F\u0647 \u0627\u0633\u062A", "\u06AF\u0648\u0634\u06CC \u0631\u0648 \u062A\u06A9\u0648\u0646 \u0628\u062F\u0647 \u062A\u0627 \u0628\u0631\u0646\u0627\u0645\u0647 \u0628\u0627\u0632 \u0628\u0634\u0647", false)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(4242, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(4242, n)
        }
        val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let {
            sm.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
    }

    private fun openIntent(): PendingIntent {
        val i = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(this, 1, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun buildNotification(channel: String, title: String, text: String, full: Boolean): Notification {
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channel) else Notification.Builder(this)
        b.setSmallIcon(R.drawable.ic_notif).setContentTitle(title).setContentText(text)
            .setContentIntent(openIntent()).setOngoing(!full).setAutoCancel(full)
        if (full) b.setFullScreenIntent(openIntent(), true)
        return b.build()
    }

    override fun onSensorChanged(e: SensorEvent) {
        val g = sqrt(e.values[0] * e.values[0] + e.values[1] * e.values[1] + e.values[2] * e.values[2]) / SensorManager.GRAVITY_EARTH
        if (g < 2.6f) return
        val now = System.currentTimeMillis()
        if (now - lastShake < 150) return
        lastShake = now
        if (now - firstShake > 900) { firstShake = now; count = 0 }
        count++
        if (count >= 3 && now - lastOpen > 3000) {
            lastOpen = now
            count = 0
            openApp()
        }
    }

    private fun openApp() {
        val canOverlay = Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(this)
        if (canOverlay) {
            try {
                startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP))
                return
            } catch (_: Exception) {}
        }
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(4243, buildNotification("konj_shake_open", "\u0628\u0627\u0632 \u06A9\u0631\u062F\u0646 Konj Planner", "\u0628\u0631\u0627\u06CC \u0628\u0627\u0632 \u0634\u062F\u0646 \u0628\u0631\u0646\u0627\u0645\u0647 \u0627\u06CC\u0646\u062C\u0627 \u0628\u0632\u0646", true))
    }

    override fun onAccuracyChanged(s: Sensor?, a: Int) {}

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        (getSystemService(Context.SENSOR_SERVICE) as SensorManager).unregisterListener(this)
        super.onDestroy()
    }
}
