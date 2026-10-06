package com.konj.planner

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class KonjPetWidgetProvider : HomeWidgetProvider() {
    private fun col(s: String?, def: String): Int =
        try { Color.parseColor(s ?: def) } catch (e: Exception) { Color.parseColor(def) }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val bg = col(widgetData.getString("wbg", null), "#1F2A2E")
        val count = widgetData.getString("petCount", "0")?.toIntOrNull() ?: 0
        val satT = widgetData.getString("petSatT", null)?.toLongOrNull() ?: System.currentTimeMillis()
        val hours = (System.currentTimeMillis() - satT) / 3600000.0

        val slots = intArrayOf(R.id.pet_s0, R.id.pet_s1, R.id.pet_s2)
        val imgs = intArrayOf(R.id.pet_img0, R.id.pet_img1, R.id.pet_img2)
        val names = intArrayOf(R.id.pet_name0, R.id.pet_name1, R.id.pet_name2)
        val infos = intArrayOf(R.id.pet_info0, R.id.pet_info1, R.id.pet_info2)
        val bars = intArrayOf(R.id.pet_sat0, R.id.pet_sat1, R.id.pet_sat2)

        appWidgetIds.forEach { id ->
            val v = RemoteViews(context.packageName, R.layout.konj_pet_widget)
            v.setInt(R.id.pet_bg, "setColorFilter", bg)
            for (i in 0..2) {
                val path = widgetData.getString("petImg" + i, "") ?: ""
                val bmp = if (i < count && path.isNotEmpty()) BitmapFactory.decodeFile(path) else null
                if (bmp == null) {
                    v.setViewVisibility(slots[i], View.GONE)
                    continue
                }
                v.setViewVisibility(slots[i], View.VISIBLE)
                v.setImageViewBitmap(imgs[i], bmp)
                v.setTextViewText(names[i], widgetData.getString("petName" + i, "") ?: "")
                v.setTextViewText(infos[i], widgetData.getString("petInfo" + i, "") ?: "")
                val sat0 = widgetData.getString("petSat" + i, "80")?.toIntOrNull() ?: 80
                val sat = Math.max(0, Math.round(sat0 - hours * 2.5).toInt())
                v.setProgressBar(bars[i], 100, sat, false)
                val idx = widgetData.getString("petIdx" + i, i.toString()) ?: i.toString()
                v.setOnClickPendingIntent(
                    slots[i],
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("konj://pet/" + idx))
                )
            }
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
