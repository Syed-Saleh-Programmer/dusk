package com.example.dusk

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class DuskQuickCaptureWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.dusk_quick_capture_widget).apply {
                val todayCount = widgetData.getInt("today_count", widgetData.getInt("dump_count", 0))
                val totalCount = widgetData.getInt("total_count", todayCount)
                val peakPeriod = widgetData.getString("peak_period", "Evening") ?: "Evening"

                val badgeText = "$todayCount Today"
                val statusText = if (totalCount > 0) {
                    "$totalCount total • Peak in $peakPeriod"
                } else {
                    "Mindful quick capture"
                }

                setTextViewText(R.id.tv_widget_today_badge, badgeText)
                setTextViewText(R.id.tv_widget_cycle_status, statusText)

                // Header tap -> Open Dusk Home
                val homeIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dusk://home/open")
                )
                setOnClickPendingIntent(R.id.widget_header_row, homeIntent)

                // 1. Thought (Text) Capture Pending Intent
                val textIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dusk://capture/text")
                )
                setOnClickPendingIntent(R.id.btn_widget_text, textIntent)

                // 2. Voice Capture Pending Intent
                val voiceIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dusk://capture/voice")
                )
                setOnClickPendingIntent(R.id.btn_widget_voice, voiceIntent)

                // 3. Photo Capture Pending Intent
                val photoIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dusk://capture/photo")
                )
                setOnClickPendingIntent(R.id.btn_widget_photo, photoIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
