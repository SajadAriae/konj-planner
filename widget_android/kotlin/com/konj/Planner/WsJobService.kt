package com.konj.planner

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.job.JobParameters
import android.app.job.JobService
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

class WsJobService : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        Thread {
            try {
                WsPoll.run(applicationContext)
            } catch (e: Exception) {
            }
            jobFinished(params, false)
        }.start()
        return true
    }

    override fun onStopJob(params: JobParameters?): Boolean = true
}

object WsPoll {
    private const val FP = "FlutterSharedPreferences"

    private class Resp(val code: Int, val text: String)

    private fun enc(s: String): String = URLEncoder.encode(s, "UTF-8")

    private fun http(method: String, url: String, headers: Map<String, String>, body: String? = null): Resp {
        val c = URL(url).openConnection() as HttpURLConnection
        try {
            c.requestMethod = method
            c.connectTimeout = 10000
            c.readTimeout = 15000
            headers.forEach { (k, v) -> c.setRequestProperty(k, v) }
            if (body != null) {
                c.doOutput = true
                c.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            }
            val code = c.responseCode
            val stream = if (code >= 400) c.errorStream else c.inputStream
            return Resp(code, stream?.bufferedReader()?.use { it.readText() } ?: "")
        } finally {
            c.disconnect()
        }
    }

    fun run(ctx: Context) {
        val fp = ctx.getSharedPreferences(FP, Context.MODE_PRIVATE)
        val base = (fp.getString("flutter.sbUrl", "") ?: "").trimEnd('/')
        val key = fp.getString("flutter.sbKey", "") ?: ""
        var token = fp.getString("flutter.sbTok", "") ?: ""
        var refresh = fp.getString("flutter.sbRef", "") ?: ""
        val uid = fp.getString("flutter.sbUid", "") ?: ""
        if (base.isEmpty() || key.isEmpty() || token.isEmpty() || uid.isEmpty()) return
        val enabled = try { fp.getBoolean("flutter.wsNotif", true) } catch (e: Exception) { true }
        if (!enabled) return

        fun get(path: String): Resp =
            http("GET", base + path, mapOf("apikey" to key, "Authorization" to "Bearer " + token))

        fun authGet(path: String): Resp {
            var r = get(path)
            if (r.code == 401 && refresh.isNotEmpty()) {
                val rr = http(
                    "POST", base + "/auth/v1/token?grant_type=refresh_token",
                    mapOf("apikey" to key, "Content-Type" to "application/json"),
                    JSONObject().put("refresh_token", refresh).toString()
                )
                if (rr.code in 200..299) {
                    val j = JSONObject(rr.text)
                    token = j.optString("access_token", token)
                    refresh = j.optString("refresh_token", refresh)
                    fp.edit().putString("flutter.sbTok", token).putString("flutter.sbRef", refresh).apply()
                    r = get(path)
                }
            }
            return r
        }

        val np = ctx.getSharedPreferences("konj_ws", Context.MODE_PRIVATE)
        val inited = np.getBoolean("inited", false)
        val seen = (np.getStringSet("seen", emptySet()) ?: emptySet()).toSet()

        // \u0648\u0638\u06CC\u0641\u0647\u200C\u0647\u0627\u06CC \u0645\u0646 \u06A9\u0647 \u0647\u0646\u0648\u0632 \u0627\u0646\u062C\u0627\u0645 \u0646\u0634\u062F\u0646
        val tq = "/rest/v1/tasks?select=" + enc("id,title,status,done_by,reward") +
            "&or=" + enc("(assignees.cs.{" + uid + "},assignee.eq." + uid + ")") + "&order=created_at.desc"
        val tr = authGet(tq)
        if (tr.code in 200..299) {
            val arr = JSONArray(tr.text)
            val mine = HashSet<String>()
            var shown = 0
            for (i in 0 until arr.length()) {
                val t = arr.getJSONObject(i)
                if (t.optString("status") == "done") continue
                val db = t.optJSONArray("done_by")
                var doneByMe = false
                if (db != null) {
                    for (k in 0 until db.length()) if (db.optString(k) == uid) doneByMe = true
                }
                if (doneByMe) continue
                val id = t.optString("id")
                mine.add(id)
                if (inited && !seen.contains(id) && shown < 5) {
                    val rw = t.optInt("reward", 0)
                    val extra = if (rw > 0) "  \uD83E\uDE99 " + rw else ""
                    notify(ctx, 6000 + (id.hashCode() and 0x1FF), "\uD83D\uDCCB \u0648\u0638\u06CC\u0641\u0647\u200C\u06CC \u062C\u062F\u06CC\u062F \u062F\u0631 \u0645\u06CC\u0632 \u06A9\u0627\u0631", t.optString("title") + extra)
                    shown++
                }
            }
            np.edit().putStringSet("seen", mine).putBoolean("inited", true).apply()
        }

        // \u0631\u0648\u06CC\u062F\u0627\u062F\u0647\u0627\u06CC \u0645\u06CC\u0632\u06A9\u0627\u0631\u0647\u0627\u06CC\u06CC \u06A9\u0647 \u0645\u062F\u06CC\u0631\u0634\u0648\u0646 \u0647\u0633\u062A\u0645: \u062A\u06CC\u06A9\u060C \u06AF\u0632\u0627\u0631\u0634\u060C \u0627\u0631\u062C\u0627\u0639\u060C \u0641\u0627\u06CC\u0644
        val mr = authGet("/rest/v1/members?user_id=eq." + uid + "&select=" + enc("workspace_id,role,workspaces(name)"))
        if (mr.code !in 200..299) return
        val ma = JSONArray(mr.text)
        val ids = ArrayList<String>()
        val names = HashMap<String, String>()
        for (i in 0 until ma.length()) {
            val m = ma.getJSONObject(i)
            val w = m.optString("workspace_id")
            names[w] = m.optJSONObject("workspaces")?.optString("name") ?: ""
            if (m.optString("role") == "manager") ids.add(w)
        }
        if (ids.isEmpty()) return
        val since = np.getString("repSeen", null)
        var rq = "/rest/v1/reports?select=" + enc("id,text,name,kind,workspace_id,created_at,user_id") +
            "&order=created_at.desc&limit=20&workspace_id=" + enc("in.(" + ids.joinToString(",") + ")")
        if (since != null) rq += "&created_at=" + enc("gt." + since)
        val rr2 = authGet(rq)
        if (rr2.code !in 200..299) return
        val ra = JSONArray(rr2.text)
        var n = 0
        for (i in 0 until ra.length()) {
            val e = ra.getJSONObject(i)
            if (since != null && e.optString("user_id") != uid && n < 5) {
                val txt = if (e.optString("kind") == "file") "\uD83D\uDCCE \u0641\u0627\u06CC\u0644 \u067E\u06CC\u0648\u0633\u062A \u06A9\u0631\u062F (" + e.optString("text") + ")" else e.optString("text")
                notify(ctx, 6500 + (e.optString("id").hashCode() and 0x1FF), "\uD83D\uDCBC " + (names[e.optString("workspace_id")] ?: ""), e.optString("name") + ": " + txt)
                n++
            }
        }
        if (ra.length() > 0) {
            np.edit().putString("repSeen", ra.getJSONObject(0).optString("created_at")).apply()
        } else if (since == null) {
            np.edit().putString("repSeen", nowIso()).apply()
        }
    }

    private fun nowIso(): String {
        val f = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.US)
        f.timeZone = java.util.TimeZone.getTimeZone("UTC")
        return f.format(java.util.Date())
    }

    private fun notify(ctx: Context, id: Int, title: String, text: String) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(NotificationChannel("konj_ws", "\u0645\u06CC\u0632 \u06A9\u0627\u0631", NotificationManager.IMPORTANCE_HIGH))
        }
        val open = PendingIntent.getActivity(
            ctx, id,
            Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, "konj_ws") else Notification.Builder(ctx)
        b.setSmallIcon(R.drawable.ic_notif).setContentTitle(title).setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text)).setContentIntent(open).setAutoCancel(true)
        nm.notify(id, b.build())
    }
}
