package com.example.dusk

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import kotlin.math.max
import kotlin.math.min

object DuskWidgetChartRenderer {

    fun getDefaultDayLabels(): List<String> {
        val fmt = SimpleDateFormat("EEE", Locale.US)
        val result = mutableListOf<String>()
        for (i in 6 downTo 0) {
            val cal = Calendar.getInstance()
            cal.add(Calendar.DAY_OF_YEAR, -i)
            val raw = fmt.format(cal.time)
            result.add(if (raw.length >= 2) raw.substring(0, 2) else raw)
        }
        return result
    }

    /**
     * Renders a crisp high-DPI dual analytics canvas tailored for Frosted Glass:
     * - Left (~63%): 7-Day Activity Bar Chart with subtle glass grid lines, count labels, and highlighted Today pill.
     * - Right (~37%): Dusk Semi-Circular Arched Gauge (Mint -> Amber -> Dusk Orange) for Evening Ritual Readiness.
     */
    fun renderActivityAndGaugeChart(
        weeklyCounts: List<Int>,
        weeklyLabels: List<String>,
        weeklyTotal: Int,
        ritualProgress: Int,
        peakPeriod: String
    ): Bitmap {
        val width = 960
        val height = 300
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val boldSans = Typeface.create("sans-serif", Typeface.BOLD)
        val regularSans = Typeface.create("sans-serif-medium", Typeface.NORMAL)

        // ==========================================
        // 1. LEFT SECTION: 7-DAY ACTIVITY BAR CHART
        // ==========================================
        val leftChartStart = 20f
        val leftChartEnd = 590f
        val leftChartWidth = leftChartEnd - leftChartStart

        // Top Metric Header ("14 past 7 days")
        val totalNumPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#1B1A19")
            textSize = 42f
            typeface = boldSans
        }
        val totalStr = weeklyTotal.toString()
        canvas.drawText(totalStr, leftChartStart, 44f, totalNumPaint)

        val totalNumWidth = totalNumPaint.measureText(totalStr)
        val subHeaderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#6E6862")
            textSize = 22f
            typeface = regularSans
        }
        canvas.drawText("captures past 7d", leftChartStart + totalNumWidth + 12f, 42f, subHeaderPaint)

        // Bar Chart Area Bounds
        val chartTop = 76f
        val chartBottom = 236f
        val chartHeight = chartBottom - chartTop

        // Subtle Frosted Glass Horizontal Reference Lines
        val gridPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#26000000") // 15% dark translucent hairline
            strokeWidth = 1.5f
            style = Paint.Style.STROKE
        }
        for (i in 0..2) {
            val y = chartTop + (chartHeight / 2f) * i
            canvas.drawLine(leftChartStart, y, leftChartEnd, y, gridPaint)
        }

        val counts = if (weeklyCounts.size == 7) weeklyCounts else List(7) { 0 }
        val labels = if (weeklyLabels.size == 7) weeklyLabels else getDefaultDayLabels()
        val maxCount = max(1, counts.maxOrNull() ?: 1)

        val slotWidth = leftChartWidth / 7f
        val barWidth = 38f
        val maxBarDrawHeight = chartHeight - 28f

        val barPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }
        val countTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = 21f
            typeface = boldSans
            textAlign = Paint.Align.CENTER
        }
        val dayTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = 21f
            textAlign = Paint.Align.CENTER
        }
        val todayPillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#59FF7A1A") // translucent peach glass pill
            style = Paint.Style.FILL
        }

        for (i in 0 until 7) {
            val count = counts[i]
            val isToday = (i == 6)
            val centerX = leftChartStart + slotWidth * i + slotWidth / 2f

            val normalized = if (maxCount > 0) (count.toFloat() / maxCount.toFloat()).coerceIn(0f, 1f) else 0f
            val barH = if (count == 0) {
                12f
            } else {
                (22f + normalized * (maxBarDrawHeight - 22f)).coerceIn(22f, maxBarDrawHeight)
            }

            val barTop = chartBottom - barH
            val barRect = RectF(
                centerX - barWidth / 2f,
                barTop,
                centerX + barWidth / 2f,
                chartBottom
            )

            if (isToday) {
                barPaint.shader = LinearGradient(
                    0f, barTop, 0f, chartBottom,
                    Color.parseColor("#FF9848"),
                    Color.parseColor("#FF7A1A"),
                    Shader.TileMode.CLAMP
                )
            } else if (count > 0) {
                barPaint.shader = LinearGradient(
                    0f, barTop, 0f, chartBottom,
                    Color.parseColor("#FFBE88"),
                    Color.parseColor("#FFA05C"),
                    Shader.TileMode.CLAMP
                )
            } else {
                barPaint.shader = null
                barPaint.color = Color.parseColor("#33000000") // 20% translucent base
            }

            canvas.drawRoundRect(barRect, 14f, 14f, barPaint)

            // Draw count label above bar if > 0
            if (count > 0) {
                countTextPaint.color = if (isToday) {
                    Color.parseColor("#FF7A1A")
                } else {
                    Color.parseColor("#1B1A19")
                }
                canvas.drawText(count.toString(), centerX, barTop - 8f, countTextPaint)
            }

            // Draw day label below bar
            val dayLabelY = 276f
            if (isToday) {
                val pillRect = RectF(centerX - 28f, 250f, centerX + 28f, 286f)
                canvas.drawRoundRect(pillRect, 12f, 12f, todayPillPaint)
                dayTextPaint.color = Color.parseColor("#C75505")
                dayTextPaint.typeface = boldSans
            } else {
                dayTextPaint.color = Color.parseColor("#6E6862")
                dayTextPaint.typeface = regularSans
            }
            canvas.drawText(labels[i], centerX, dayLabelY, dayTextPaint)
        }

        // ==========================================
        // 2. VERTICAL GLASS DIVIDER
        // ==========================================
        val dividerX = 616f
        val dividerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#33000000") // translucent glass divider
            strokeWidth = 2f
        }
        canvas.drawLine(dividerX, 18f, dividerX, height - 18f, dividerPaint)

        // ==========================================
        // 3. RIGHT SECTION: RITUAL ARC GAUGE & RHYTHM
        // ==========================================
        val rightCenterX = 790f
        val arcCenterY = 178f
        val arcRadius = 112f
        val strokeW = 24f

        val arcRect = RectF(
            rightCenterX - arcRadius,
            arcCenterY - arcRadius,
            rightCenterX + arcRadius,
            arcCenterY + arcRadius
        )

        // Translucent Background Track Arc
        val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#26000000")
            style = Paint.Style.STROKE
            strokeWidth = strokeW
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawArc(arcRect, 180f, 180f, false, trackPaint)

        // Glowing Gradient Arc (Mint -> Sunny Amber -> Dusk Orange)
        val clampedPct = ritualProgress.coerceIn(0, 100) / 100f
        val displayPct = if (clampedPct == 0f && weeklyTotal > 0) 0.25f else clampedPct
        if (displayPct > 0f) {
            val progressPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(
                    rightCenterX - arcRadius, arcCenterY,
                    rightCenterX + arcRadius, arcCenterY,
                    intArrayOf(
                        Color.parseColor("#2DC48D"),
                        Color.parseColor("#F6C343"),
                        Color.parseColor("#FF7A1A")
                    ),
                    floatArrayOf(0f, 0.5f, 1f),
                    Shader.TileMode.CLAMP
                )
                style = Paint.Style.STROKE
                strokeWidth = strokeW
                strokeCap = Paint.Cap.ROUND
            }
            canvas.drawArc(arcRect, 180f, 180f * displayPct, false, progressPaint)
        }

        // Center Percentage Text inside Gauge
        val pctPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#1B1A19")
            textSize = 46f
            typeface = boldSans
            textAlign = Paint.Align.CENTER
        }
        canvas.drawText("${ritualProgress.coerceIn(0, 100)}%", rightCenterX, arcCenterY - 18f, pctPaint)

        val gaugeSubPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#6E6862")
            textSize = 20f
            typeface = regularSans
            textAlign = Paint.Align.CENTER
        }
        canvas.drawText("Ritual Ready", rightCenterX, arcCenterY + 12f, gaugeSubPaint)

        // Peak Rhythm Glass Pill below Gauge
        val cleanPeak = if (peakPeriod.isNotBlank()) peakPeriod else "Evening"
        val peakText = "Peak: $cleanPeak"
        val peakTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#C75505")
            textSize = 20f
            typeface = boldSans
            textAlign = Paint.Align.CENTER
        }
        val textW = peakTextPaint.measureText(peakText)
        val pillHalfW = max(92f, textW / 2f + 22f)
        val peakPillRect = RectF(
            rightCenterX - pillHalfW,
            236f,
            rightCenterX + pillHalfW,
            280f
        )
        val peakPillBgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#4DFFFFFF") // frosted glass fill
            style = Paint.Style.FILL
        }
        val peakPillStrokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#80FF9646") // translucent peach glass stroke
            style = Paint.Style.STROKE
            strokeWidth = 2f
        }
        canvas.drawRoundRect(peakPillRect, 22f, 22f, peakPillBgPaint)
        canvas.drawRoundRect(peakPillRect, 22f, 22f, peakPillStrokePaint)
        canvas.drawText(peakText, rightCenterX, 265f, peakTextPaint)

        return bitmap
    }

    /**
     * Renders the proportional horizontal stacked glass bar for Thoughts (#FF7A1A),
     * Voice (#4A84D8), and Moments (#2DC48D).
     */
    fun renderBreakdownBar(
        thoughtCount: Int,
        voiceCount: Int,
        photoCount: Int
    ): Bitmap {
        val width = 960
        val height = 20
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val total = thoughtCount + voiceCount + photoCount
        val radius = 10f
        val gap = 8f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }

        if (total <= 0) {
            // Subtle 3-tone translucent preview track when empty
            val segW = (width - gap * 2f) / 3f
            val colors = listOf("#4DFF7A1A", "#4D4A84D8", "#4D2DC48D")
            for (i in 0..2) {
                paint.color = Color.parseColor(colors[i])
                val startX = i * (segW + gap)
                canvas.drawRoundRect(RectF(startX, 0f, startX + segW, height.toFloat()), radius, radius, paint)
            }
            return bitmap
        }

        data class Segment(val count: Int, val colorHex: String)
        val activeSegments = listOf(
            Segment(thoughtCount, "#FF7A1A"),
            Segment(voiceCount, "#4A84D8"),
            Segment(photoCount, "#2DC48D")
        ).filter { it.count > 0 }

        val totalGaps = (activeSegments.size - 1) * gap
        val availWidth = width - totalGaps
        var currentX = 0f

        for (i in activeSegments.indices) {
            val seg = activeSegments[i]
            val ratio = seg.count.toFloat() / total.toFloat()
            val segW = if (i == activeSegments.lastIndex) {
                max(16f, width - currentX)
            } else {
                max(16f, availWidth * ratio)
            }
            paint.color = Color.parseColor(seg.colorHex)
            val rect = RectF(currentX, 0f, min(width.toFloat(), currentX + segW), height.toFloat())
            canvas.drawRoundRect(rect, radius, radius, paint)
            currentX += segW + gap
        }

        return bitmap
    }
}
