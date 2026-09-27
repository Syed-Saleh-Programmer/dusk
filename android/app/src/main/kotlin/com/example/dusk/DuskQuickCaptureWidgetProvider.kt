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
                val dumpCount = widgetData.getInt("dump_count", 0)
                val statusText = if (dumpCount > 0) {
                    "$dumpCount capture${if (dumpCount == 1) "" else "s"} today"
                } else {
                    "Tap to capture freely"
                }
                setTextViewText(R.id.tv_widget_cycle_status, statusText)

                // 1. Text Capture Pending Intent
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
