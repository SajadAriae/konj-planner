package com.konj.planner

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

class KonjWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = Factory(applicationContext)

    class Factory(private val ctx: Context) : RemoteViewsFactory {
        private var items = JSONArray()
        private var acc = Color.parseColor("#4DB6AC")

        private fun load() {
            val p = ctx.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            items = try { JSONArray(p.getString("items", "[]")) } catch (e: Exception) { JSONArray() }
            acc = try { Color.parseColor(p.getString("wacc", "#4DB6AC")) } catch (e: Exception) { Color.parseColor("#4DB6AC") }
        }

        override fun onCreate() = load()
        override fun onDataSetChanged() = load()
        override fun onDestroy() {}
        override fun getCount(): Int = items.length()
        override fun getLoadingView(): RemoteViews? = null
        override fun getViewTypeCount(): Int = 1
        override fun getItemId(position: Int): Long = position.toLong()
        override fun hasStableIds(): Boolean = true

        override fun getViewAt(position: Int): RemoteViews {
            val v = RemoteViews(ctx.packageName, R.layout.konj_widget_item)
            val o = items.optJSONObject(position) ?: return v
            val kind = o.optString("k")
            val id = o.optString("id")
            val done = o.optBoolean("d", false)
            val isHabit = kind == "h"
            val ic = o.optString("i", "")
            v.setTextViewText(R.id.item_icon, if (ic.isNotEmpty()) ic else if (isHabit) (if (done) "\u2705" else "\uD83D\uDD25") else "\u2610")
            v.setTextViewText(R.id.item_text, o.optString("t"))
            v.setTextColor(R.id.item_text, if (done) Color.parseColor("#99FFFFFF") else Color.WHITE)
            v.setTextColor(R.id.item_icon, if (isHabit) acc else Color.WHITE)
            val fill = Intent().apply {
                data = Uri.parse(if (isHabit) "konj://habit/$id" else "konj://done/$id")
            }
            v.setOnClickFillInIntent(R.id.item_root, fill)
            return v
        }
    }
}
