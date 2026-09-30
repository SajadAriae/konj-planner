package com.konj.planner

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
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
                val openTasks = widgetData.getString("openTasks", "0") ?: "0"
                val overdueTasks = widgetData.getString("overdueTasks", "0") ?: "0"
                val goalTitle = widgetData.getString("goalTitle", "هنوز هدفی ثبت نشده") ?: "هنوز هدفی ثبت نشده"
                val goalProgress = widgetData.getString("goalProgress", "0") ?: "0"
                val today = widgetData.getString("today", "") ?: ""

                setTextViewText(R.id.widget_today, today)
                setTextViewText(R.id.widget_open_tasks, "کارهای باز: $openTasks")
                setTextViewText(R.id.widget_overdue_tasks, "عقب‌افتاده: $overdueTasks")
                setTextViewText(R.id.widget_goal_title, goalTitle)
                setTextViewText(R.id.widget_goal_progress, "$goalProgress٪")

                val launchIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, launchIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
