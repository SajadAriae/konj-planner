package com.konj.planner

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class KonjPlannerWidgetProvider : HomeWidgetProvider() {

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
        val count = try { JSONArray(widgetData.getString("items", "[]")).length() } catch (e: Exception) { 0 }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.konj_planner_widget).apply {
                setInt(R.id.widget_bg, "setColorFilter", bg)
                setTextColor(R.id.widget_title, Color.WHITE)
                setTextColor(R.id.widget_summary, acc.let { lighten(it) })
                setTextViewText(R.id.widget_today, widgetData.getString("today", "") ?: "")
                setTextViewText(R.id.widget_summary, widgetData.getString("summary", "") ?: "")
                setInt(R.id.widget_add_task, "setBackgroundColor", acc)
                setInt(R.id.widget_add_tx, "setBackgroundColor", acc)

                // لیست اسکرول‌شونده‌ی کارها و عادت‌ها
                val svc = Intent(context, KonjWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                setRemoteAdapter(R.id.widget_list, svc)
                setEmptyView(R.id.widget_list, R.id.widget_empty)

                // قالب کلیک ردیف‌ها: تیک زدن بدون باز شدن برنامه
                val tpl = Intent().apply {
                    component = ComponentName(context, "es.antonborri.home_widget.HomeWidgetBackgroundReceiver")
                    action = "es.antonborri.home_widget.action.BACKGROUND"
                }
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                        (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
                setPendingIntentTemplate(R.id.widget_list, PendingIntent.getBroadcast(context, 0, tpl, flags))

                setOnClickPendingIntent(
                    R.id.widget_add_task,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("konj://addtask"))
                )
                setOnClickPendingIntent(
                    R.id.widget_add_tx,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("konj://addtx"))
                )
                val open = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_header, open)
                setOnClickPendingIntent(R.id.widget_empty, open)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
        }
    }

    private fun lighten(c: Int): Int {
        val hsv = FloatArray(3)
        Color.colorToHSV(c, hsv)
        hsv[1] = hsv[1] * 0.45f
        hsv[2] = 1f
        return Color.HSVToColor(hsv)
    }
}
