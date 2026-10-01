package com.konj.planner

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class KonjPlannerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.konj_planner_widget).apply {
                val open = widgetData.getString("openTasks", "0") ?: "0"
                val overdue = widgetData.getString("overdueTasks", "0") ?: "0"
                val goal = widgetData.getString("goalTitle", "") ?: ""
                val progress = widgetData.getString("goalProgress", "0") ?: "0"

                setTextViewText(R.id.widget_today, widgetData.getString("today", "") ?: "")
                setTextViewText(R.id.widget_summary, "باز: $open   |   عقب‌افتاده: $overdue")
                setTextViewText(R.id.widget_goal_title, if (goal.isEmpty()) "" else "هدف: $goal — $progress٪")

                val rows = intArrayOf(R.id.widget_t1, R.id.widget_t2, R.id.widget_t3)
                var shown = 0
                for (i in 0..2) {
                    val title = widgetData.getString("t${i + 1}", "") ?: ""
                    val id = widgetData.getString("t${i + 1}id", "") ?: ""
                    if (title.isEmpty() || id.isEmpty()) {
                        setViewVisibility(rows[i], View.GONE)
                    } else {
                        shown++
                        setViewVisibility(rows[i], View.VISIBLE)
                        setTextViewText(rows[i], "☐  $title")
                        // تیک زدن مستقیم از ویجت، بدون باز شدن برنامه
                        setOnClickPendingIntent(
                            rows[i],
                            HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("konj://done/$id"))
                        )
                    }
                }
                if (shown == 0) {
                    setViewVisibility(R.id.widget_t1, View.VISIBLE)
                    setTextViewText(R.id.widget_t1, "کاری باقی نمونده 🎉")
                }

                setOnClickPendingIntent(
                    R.id.widget_add_task,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("konj://addtask"))
                )
                setOnClickPendingIntent(
                    R.id.widget_add_tx,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("konj://addtx"))
                )
                setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
