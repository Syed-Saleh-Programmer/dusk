package com.example.dusk

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class DuskVoiceTextWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.dusk_voice_text_widget).apply {
                val thoughtCount = widgetData.getInt("thought_count", 0)
                val voiceCount = widgetData.getInt("voice_count", 0)

                setTextViewText(R.id.tv_split_thought_count, thoughtCount.toString())
                setTextViewText(
                    R.id.tv_split_thought_sub,
                    if (thoughtCount > 0) "$thoughtCount saved" else "Write note"
                )

                setTextViewText(R.id.tv_split_voice_count, voiceCount.toString())
                setTextViewText(
                    R.id.tv_split_voice_sub,
                    if (voiceCount > 0) "$voiceCount saved" else "Audio memo"
                )

                // 1. Thought (Text) Capture Pending Intent
                val textIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dusk://capture/text")
                )
                setOnClickPendingIntent(R.id.btn_split_thought, textIntent)

                // 2. Voice Capture Pending Intent
                val voiceIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dusk://capture/voice")
                )
                setOnClickPendingIntent(R.id.btn_split_voice, voiceIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
