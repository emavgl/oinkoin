package com.example.piggybank.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.BitmapFactory
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import com.example.piggybank.R
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

/**
 * Base for Oinkoin home screen widgets. All texts, colors and the sparkline
 * image are pushed from Flutter ([HomeWidgetService]) as data keys, so the
 * system renders crisp text at any widget size. Bitmaps are only used for
 * the small sparkline charts.
 */
abstract class OinkoinWidgetProvider : HomeWidgetProvider() {

    protected enum class Kind { OVERVIEW, SINGLE, BUDGET }

    protected abstract val kind: Kind

    /** Key prefix for this widget type, e.g. `oinkoin_income`. */
    protected abstract val keyPrefix: String

    /**
     * Suffix appended for per-instance widgets (budget): the Android widget
     * id, so each pinned instance shows its own budget. Null for shared
     * single-image widgets.
     */
    protected open fun instanceSuffix(
        context: Context,
        appWidgetId: Int,
    ): String? = null

    private fun key(name: String, suffix: String?): String =
        if (suffix == null) "${keyPrefix}_$name" else "${keyPrefix}_${suffix}_$name"

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(
            context, appWidgetManager, appWidgetId, newOptions,
        )
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    /** Compact single-value layout when the widget is shorter than ~110dp. */
    private fun isCompact(
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ): Boolean {
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minHeight =
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        return minHeight > 0 && minHeight < 110
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences,
    ) {
        val dark = widgetData.getBoolean("oinkoin_dark", true)
        val titleColor = if (dark) 0xFFFFFFFF.toInt() else 0xFF000000.toInt()
        for (appWidgetId in appWidgetIds) {
            val suffix = instanceSuffix(context, appWidgetId)
            val compact = isCompact(appWidgetManager, appWidgetId)
            val views = RemoteViews(
                context.packageName,
                when {
                    compact && kind == Kind.BUDGET ->
                        R.layout.oinkoin_compact_budget
                    compact -> R.layout.oinkoin_compact_value
                    kind == Kind.OVERVIEW -> R.layout.oinkoin_stats_widget
                    kind == Kind.SINGLE -> R.layout.oinkoin_single_widget
                    else -> R.layout.oinkoin_budget_widget
                },
            )
            views.setInt(
                R.id.widget_root,
                "setBackgroundResource",
                if (dark) R.drawable.oinkoin_widget_bg_dark
                else R.drawable.oinkoin_widget_bg_light,
            )
            var hasContent = false
            if (compact) {
                hasContent = when (kind) {
                    Kind.BUDGET -> bindCompactBudget(
                        views, widgetData, suffix, titleColor,
                    )
                    Kind.OVERVIEW -> bindCompactValue(
                        views,
                        widgetData,
                        textOrNull(widgetData, "balance", suffix),
                        widgetData.getInt(
                            key("balance_color", suffix), titleColor),
                    )
                    Kind.SINGLE -> bindCompactValue(
                        views,
                        widgetData,
                        textOrNull(widgetData, "value", suffix),
                        widgetData.getInt(key("color", suffix), titleColor),
                    )
                }
            } else when (kind) {
                Kind.OVERVIEW -> {
                    hasContent = bindTriple(context, views, widgetData, suffix, titleColor)
                }
                Kind.SINGLE -> {
                    hasContent = bindSingle(context, views, widgetData, suffix, titleColor)
                }
                Kind.BUDGET -> {
                    hasContent = bindBudget(context, views, widgetData, suffix, titleColor)
                }
            }
            views.setViewVisibility(
                R.id.widget_placeholder,
                if (hasContent) View.GONE else View.VISIBLE,
            )
            val launchIntent =
                context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    appWidgetId,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun textOrNull(
        widgetData: android.content.SharedPreferences,
        name: String,
        suffix: String?,
    ): String? = widgetData.getString(key(name, suffix), null)

    private fun bindTriple(
        context: Context,
        views: RemoteViews,
        widgetData: android.content.SharedPreferences,
        suffix: String?,
        titleColor: Int,
    ): Boolean {
        val labels = arrayOf(
            textOrNull(widgetData, "label_income", suffix),
            textOrNull(widgetData, "label_expenses", suffix),
            textOrNull(widgetData, "label_balance", suffix),
        )
        val values = arrayOf(
            textOrNull(widgetData, "income", suffix),
            textOrNull(widgetData, "expenses", suffix),
            textOrNull(widgetData, "balance", suffix),
        )
        if (values.all { it.isNullOrEmpty() }) return false
        val labelIds = intArrayOf(R.id.widget_label_1, R.id.widget_label_2, R.id.widget_label_3)
        val valueIds = intArrayOf(R.id.widget_value_1, R.id.widget_value_2, R.id.widget_value_3)
        val dotIds = intArrayOf(R.id.widget_dot_1, R.id.widget_dot_2, R.id.widget_dot_3)
        val colorKeys = arrayOf("income_color", "expenses_color", "balance_color")
        for (i in 0..2) {
            views.setTextViewText(labelIds[i], labels[i] ?: "")
            views.setTextViewText(valueIds[i], values[i] ?: "")
            val color = widgetData.getInt(colorKeys[i].let { key(it, suffix) }, titleColor)
            views.setTextColor(valueIds[i], color)
            views.setTextColor(labelIds[i], 0xFF808080.toInt())
            views.setInt(dotIds[i], "setColorFilter", color)
        }
        bindSpark(views, widgetData, "spark", suffix)
        return true
    }

    private fun bindCompactValue(
        views: RemoteViews,
        widgetData: android.content.SharedPreferences,
        value: String?,
        color: Int,
    ): Boolean {
        if (value.isNullOrEmpty()) return false
        views.setTextViewText(R.id.widget_value, value)
        views.setTextColor(R.id.widget_value, color)
        return true
    }

    private fun bindCompactBudget(
        views: RemoteViews,
        widgetData: android.content.SharedPreferences,
        suffix: String?,
        titleColor: Int,
    ): Boolean {
        val name = textOrNull(widgetData, "name", suffix)
        if (name.isNullOrEmpty()) return false
        views.setTextViewText(R.id.widget_name, name)
        views.setTextColor(R.id.widget_name, titleColor)
        views.setInt(
            R.id.widget_dot,
            "setColorFilter",
            widgetData.getInt(key("color", suffix), titleColor),
        )
        views.setProgressBar(
            R.id.widget_bar,
            100,
            widgetData.getInt(key("ratio", suffix), 0),
            false,
        )
        return true
    }

    private fun bindSpark(
        views: RemoteViews,
        widgetData: android.content.SharedPreferences,
        name: String,
        suffix: String?,
    ) {
        val sparkPath = textOrNull(widgetData, name, suffix)?.let { File(it) }
        if (sparkPath != null && sparkPath.exists()) {
            val bitmap = BitmapFactory.decodeFile(sparkPath.absolutePath)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_spark, bitmap)
            }
        }
    }

    private fun bindSingle(
        context: Context,
        views: RemoteViews,
        widgetData: android.content.SharedPreferences,
        suffix: String?,
        titleColor: Int,
    ): Boolean {
        val value = textOrNull(widgetData, "value", suffix)
        if (value.isNullOrEmpty()) return false
        val color = widgetData.getInt(key("color", suffix), titleColor)
        views.setTextViewText(R.id.widget_label, textOrNull(widgetData, "label", suffix) ?: "")
        views.setTextViewText(R.id.widget_value, value)
        views.setTextColor(R.id.widget_value, color)
        views.setTextColor(R.id.widget_label, 0xFF808080.toInt())
        views.setInt(R.id.widget_dot, "setColorFilter", color)
        bindSpark(views, widgetData, "spark", suffix)
        return true
    }

    private fun bindBudget(
        context: Context,
        views: RemoteViews,
        widgetData: android.content.SharedPreferences,
        suffix: String?,
        titleColor: Int,
    ): Boolean {
        val name = textOrNull(widgetData, "name", suffix)
        if (name.isNullOrEmpty()) return false
        val color = widgetData.getInt(key("color", suffix), titleColor)
        views.setTextViewText(R.id.widget_name, name)
        views.setTextColor(R.id.widget_name, titleColor)
        views.setInt(R.id.widget_dot, "setColorFilter", color)
        views.setTextViewText(
            R.id.widget_progress,
            textOrNull(widgetData, "progress", suffix) ?: "",
        )
        views.setProgressBar(
            R.id.widget_bar,
            100,
            widgetData.getInt(key("ratio", suffix), 0),
            false,
        )
        views.setTextColor(
            R.id.widget_progress,
            widgetData.getInt(key("color", suffix), titleColor),
        )
        return true
    }
}
