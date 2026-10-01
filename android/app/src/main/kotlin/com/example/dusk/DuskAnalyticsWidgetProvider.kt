package com.example.dusk

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import kotlin.math.roundToInt

class DuskAnalyticsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.dusk_analytics_widget).apply {
                val todayCount = widgetData.getInt("today_count", widgetData.getInt("dump_count", 0))
                val totalCount = widgetData.getInt("total_count", todayCount)
                val thoughtCount = widgetData.getInt("thought_count", 0)
                val voiceCount = widgetData.getInt("voice_count", 0)
                val photoCount = widgetData.getInt("photo_count", 0)
                val activeDays = widgetData.getInt("active_days", if (todayCount > 0) 1 else 0)
                val ritualProgress = widgetData.getInt(
                    "ritual_progress",
                    ((totalCount.coerceAtMost(4) / 4f) * 100f).roundToInt()
                )
                val ritualCompleted = widgetData.getBoolean("ritual_completed", false)
                val peakPeriod = widgetData.getString("peak_period", "Evening") ?: "Evening"

                val rawWeeklyCounts = widgetData.getString("weekly_counts", "") ?: ""
                val weeklyCounts = if (rawWeeklyCounts.isNotBlank()) {
                    rawWeeklyCounts.split(",").mapNotNull { it.trim().toIntOrNull() }
                } else {
                    listOf(0, 0, 0, 0, 0, 0, todayCount)
                }

                val rawWeeklyLabels = widgetData.getString("weekly_labels", "") ?: ""
                val weeklyLabels = if (rawWeeklyLabels.isNotBlank()) {
                    rawWeeklyLabels.split(",").map { it.trim() }
                } else {
                    DuskWidgetChartRenderer.getDefaultDayLabels()
                }

                val weeklyTotal = weeklyCounts.sum()

                // 1. Header Badges & Subtitle
                setTextViewText(R.id.tv_analytics_today_badge, "$todayCount Today")
                setTextViewText(R.id.tv_analytics_streak_badge, "$activeDays/7 Days")
                setTextViewText(
                    R.id.tv_analytics_subtitle,
                    if (totalCount > 0) {
                        "$totalCount total captures • Peak in $peakPeriod"
                    } else {
                        "7-Day Activity & Capture Breakdown"
                    }
                )

                // 2. Render High-DPI 7-Day Activity Bar Graph + Ritual Readiness Arc Gauge
                val mainChartBitmap = DuskWidgetChartRenderer.renderActivityAndGaugeChart(
                    weeklyCounts = weeklyCounts,
                    weeklyLabels = weeklyLabels,
                    weeklyTotal = weeklyTotal,
                    ritualProgress = if (ritualCompleted) 100 else ritualProgress,
                    peakPeriod = peakPeriod
                )
                setImageViewBitmap(R.id.iv_analytics_chart, mainChartBitmap)

                // 3. Render Proportional Multi-Segment Breakdown Bar
                val breakdownBitmap = DuskWidgetChartRenderer.renderBreakdownBar(
                    thoughtCount = thoughtCount,
                    voiceCount = voiceCount,
                    photoCount = photoCount
                )
                setImageViewBitmap(R.id.iv_breakdown_bar, breakdownBitmap)

                // 4. Modality Counts & Percentages
                val denom = (thoughtCount + voiceCount + photoCount).coerceAtLeast(1)
                val thoughtPct = if (totalCount > 0) ((thoughtCount * 100f) / denom).roundToInt() else 0
                val voicePct = if (totalCount > 0) ((voiceCount * 100f) / denom).roundToInt() else 0
                val photoPct = if (totalCount > 0) ((photoCount * 100f) / denom).roundToInt() else 0

                setTextViewText(R.id.tv_analytics_thought_count, "$thoughtCount · $thoughtPct%")
                setTextViewText(R.id.tv_analytics_voice_count, "$voiceCount · $voicePct%")
                setTextViewText(R.id.tv_analytics_photo_count, "$photoCount · $photoPct%")

                // 5. Evening Ritual Status Strip
                val ritualStatusText = if (ritualCompleted) {
                    "Evening Reflection complete ✨"
                } else {
                    "9:00 PM Ritual • $ritualProgress% ready ($todayCount today)"
                }
                setTextViewText(R.id.tv_analytics_ritual_status, ritualStatusText)

                // 6. PendingIntents for Interactive Touch Targets
                val openAnalyticsIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dusk://home/analytics")
                )
                setOnClickPendingIntent(R.id.analytics_header_row, openAnalyticsIntent)
                setOnClickPendingIntent(R.id.analytics_chart_container, openAnalyticsIntent)

                val textIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dusk://capture/text")
                )
                setOnClickPendingIntent(R.id.btn_analytics_thought, textIntent)

                val voiceIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dusk://capture/voice")
                )
                setOnClickPendingIntent(R.id.btn_analytics_voice, voiceIntent)

                val photoIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dusk://capture/photo")
                )
                setOnClickPendingIntent(R.id.btn_analytics_photo, photoIntent)

                val ritualIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dusk://home/ritual")
                )
                setOnClickPendingIntent(R.id.btn_analytics_ritual, ritualIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
