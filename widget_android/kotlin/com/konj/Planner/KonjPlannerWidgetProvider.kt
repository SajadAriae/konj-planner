package com.konj.planner

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
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
        val acc = col(widgetData.getString("wacc", null), "#2E9E8A")
        val path = widgetData.getString("petImg", "") ?: ""
        val bmp = if (path.isNotEmpty()) BitmapFactory.decodeFile(path) else null
        val sat0 = try { widgetData.getInt("petSat", 80) } catch (e: Exception) { 80 }
        val satT = try { widgetData.getLong("petSatT", System.currentTimeMillis()) } catch (e: Exception) { System.currentTimeMillis() }
        val hours = (System.currentTimeMillis() - satT) / 3600000.0
        val sat = Math.max(0, Math.round(sat0 - hours * 2.5).toInt())

        appWidgetIds.forEach { id ->
            val v = RemoteViews(context.packageName, R.layout.konj_pet_widget)
            v.setInt(R.id.pet_bg, "setColorFilter", bg)
            if (bmp != null) v.setImageViewBitmap(R.id.pet_img, bmp)
            v.setTextViewText(R.id.pet_name, widgetData.getString("petName", "") ?: "")
            val info = widgetData.getString("petInfo", "") ?: ""
            v.setTextViewText(R.id.pet_info, if (sat < 25 && info.isNotEmpty()) info + "  \uD83C\uDF56" else info)
            v.setProgressBar(R.id.pet_sat, 100, sat, false)
            v.setTextViewText(R.id.pet_btn, widgetData.getString("petBtn", "") ?: "")
            v.setInt(R.id.pet_btn, "setBackgroundColor", acc)
            val open = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("konj://pet"))
            v.setOnClickPendingIntent(R.id.pet_root, open)
            v.setOnClickPendingIntent(R.id.pet_btn, open)
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
