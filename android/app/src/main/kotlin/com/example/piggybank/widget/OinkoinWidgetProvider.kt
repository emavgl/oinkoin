package com.example.piggybank.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import com.example.piggybank.MainActivity
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
        if (suffix == null) {
            "${keyPrefix}_$name"
        } else {
            "${keyPrefix}_${suffix}_$name"
        }

    private fun actionIntent(
        context: Context,
        action: String,
        appWidgetId: Int,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = action
        }
        return PendingIntent.getActivity(
            context,
            appWidgetId * 10 + requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        const val TAG = "OinkoinWidget"
        const val ACTION_ADD_EXPENSE = "com.example.piggybank.ADD_EXPENSE"
        const val ACTION_ADD_INCOME = "com.example.piggybank.ADD_INCOME"
    }

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

    /**
     * Tints the rounded widget background with the app's own surface color,
     * sent by Dart (dynamic seed theme, so it can't be hardcoded). No-op
     * when the key is absent (older data) or the OS predates S, where
     * background tinting isn't available to RemoteViews — gradient stays.
     */
    private fun applyAppBackground(
        views: RemoteViews,
        widgetData: android.content.SharedPreferences,
    ) {
        val fullKey = "oinkoin_background_color"
        if (!widgetData.contains(fullKey)) return
        val bg = try {
            widgetData.getInt(fullKey, 0)
        } catch (e: ClassCastException) {
            try {
                widgetData.getLong(fullKey, 0L).toInt()
            } catch (e2: Exception) {
                return
            }
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            views.setColorStateList(
                R.id.widget_root,
                "setBackgroundTintList",
                android.content.res.ColorStateList.valueOf(bg),
            )
        }
    }

    /** Wires the quick-add minus/plus buttons. Missing views are ignored. */
    private fun bindQuickAdd(
        context: Context,
        views: RemoteViews,
        appWidgetId: Int,
    ) {
        // Quick-add shortcuts: minus opens the expense flow, plus income.
        views.setOnClickPendingIntent(
            R.id.widget_action_minus,
            actionIntent(context, ACTION_ADD_EXPENSE, appWidgetId, 1),
        )
        views.setOnClickPendingIntent(
            R.id.widget_action_plus,
            actionIntent(context, ACTION_ADD_INCOME, appWidgetId, 2),
        )
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
            try {
                updateSingleWidget(context, appWidgetManager, appWidgetId, widgetData, dark, titleColor)
            } catch (e: Exception) {
                android.util.Log.e("OinkoinWidget", "Failed to update widget $appWidgetId", e)
            }
        }
    }

    private fun updateSingleWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        widgetData: android.content.SharedPreferences,
        dark: Boolean,
        titleColor: Int,
    ) {
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
        applyAppBackground(views, widgetData)
        // Divider above the quick-add row: light gray in dark mode, dark in light.
        views.setInt(
            R.id.widget_divider,
            "setBackgroundColor",
            if (dark) 0x4DFFFFFF.toInt() else 0x4D000000.toInt(),
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
                    getColor(widgetData, "balance_color", suffix, titleColor),
                )
                Kind.SINGLE -> bindCompactValue(
                    views,
                    widgetData,
                    textOrNull(widgetData, "value", suffix),
                    getColor(widgetData, "color", suffix, titleColor),
                )
            }
        } else when (kind) {
            Kind.OVERVIEW -> {
                hasContent = bindTriple(context, views, widgetData, suffix, titleColor)
                if (hasContent) bindQuickAdd(context, views, appWidgetId)
            }
            Kind.SINGLE -> {
                hasContent = bindSingle(context, views, widgetData, suffix, titleColor, appWidgetId)
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

    private fun textOrNull(
        widgetData: android.content.SharedPreferences,
        name: String,
        suffix: String?,
    ): String? = widgetData.getString(key(name, suffix), null)

    /**
     * Reads a color int robustly. Dart ints above 2^31 (every opaque ARGB
     * color) arrive as Long, on which getInt() throws ClassCastException —
     * aborting the whole widget update. Never let a color break the update.
     */
    private fun getColor(
        widgetData: android.content.SharedPreferences,
        name: String,
        suffix: String?,
        default: Int,
    ): Int {
        val fullKey = key(name, suffix)
        try {
            return widgetData.getInt(fullKey, default)
        } catch (e: ClassCastException) {
            // Stored as Long, fall through.
        }
        return try {
            widgetData.getLong(fullKey, default.toLong()).toInt()
        } catch (e: Exception) {
            default
        }
    }

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
        val colorKeys = arrayOf("income_color", "expenses_color", "balance_color")
        for (i in 0..2) {
            views.setTextViewText(labelIds[i], labels[i] ?: "")
            views.setTextViewText(valueIds[i], values[i] ?: "")
            val color = getColor(widgetData, colorKeys[i], suffix, titleColor)
            views.setTextColor(valueIds[i], color)
            views.setTextColor(labelIds[i], 0xFF808080.toInt())
        }
        bindSpark(views, widgetData, "spark", suffix)
        // Balance dot follows the sign: red when negative, green otherwise.
        // Derived from the balance color channels (setColorFilter reflection
        // proved unreliable, so the baked drawables are swapped instead).
        val balanceColor = getColor(widgetData, "balance_color", suffix, titleColor)
        val red = (balanceColor shr 16) and 0xFF
        val green = (balanceColor shr 8) and 0xFF
        views.setImageViewResource(
            R.id.widget_dot_3,
            if (red > green) R.drawable.oinkoin_widget_dot_red
            else R.drawable.oinkoin_widget_dot_green,
        )
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
        if (name.isNullOrEmpty()) {
            for (id in intArrayOf(R.id.widget_name, R.id.widget_bar)) {
                views.setViewVisibility(id, View.GONE)
            }
            return false
        }
        val color = getColor(widgetData, "color", suffix, titleColor)
        views.setTextViewText(R.id.widget_name, name)
        views.setTextColor(R.id.widget_name, titleColor)
        val ratio = (widgetData.getInt(key("ratio", suffix), 0)).coerceIn(0, 100)
        views.setImageViewBitmap(R.id.widget_bar, drawBar(color, titleColor, ratio))
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
        appWidgetId: Int,
    ): Boolean {
        val value = textOrNull(widgetData, "value", suffix)
        if (value.isNullOrEmpty()) return false
        val color = getColor(widgetData, "color", suffix, titleColor)
        views.setTextViewText(R.id.widget_label, textOrNull(widgetData, "label", suffix) ?: "")
        views.setTextViewText(R.id.widget_value, value)
        views.setTextColor(R.id.widget_value, color)
        views.setTextColor(R.id.widget_label, 0xFF808080.toInt())
        // Dot follows the widget kind: green income, red expenses, hidden for balance.
        when (keyPrefix) {
            "oinkoin_income" -> views.setImageViewResource(
                R.id.widget_dot, R.drawable.oinkoin_widget_dot_green,
            )
            "oinkoin_expenses" -> views.setImageViewResource(
                R.id.widget_dot, R.drawable.oinkoin_widget_dot_red,
            )
            else -> views.setViewVisibility(R.id.widget_dot, View.GONE)
        }
        bindSpark(views, widgetData, "spark", suffix)
        bindQuickAdd(context, views, appWidgetId)
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
        if (name.isNullOrEmpty()) {
            for (id in intArrayOf(
                R.id.widget_icon, R.id.widget_name, R.id.widget_cycle,
                R.id.widget_bar, R.id.widget_amount, R.id.widget_percent,
            )) {
                views.setViewVisibility(id, View.GONE)
            }
            return false
        }
        val color = getColor(widgetData, "color", suffix, titleColor)
        // The card mirrors the budgets page: icon + name + cycle on top,
        // a colored progress bar, then "spent / target" and the percentage.
        val saving = widgetData.getString(key("type", suffix), null) == "saving"
        views.setImageViewResource(
            R.id.widget_icon,
            if (saving) R.drawable.oinkoin_ic_budget_saving
            else R.drawable.oinkoin_ic_budget_expense,
        )
        views.setTextViewText(R.id.widget_name, name)
        views.setTextColor(R.id.widget_name, titleColor)
        views.setTextViewText(
            R.id.widget_cycle,
            textOrNull(widgetData, "cycle", suffix) ?: "",
        )
        views.setTextViewText(
            R.id.widget_amount,
            textOrNull(widgetData, "progress", suffix) ?: "",
        )
        views.setTextViewText(
            R.id.widget_percent,
            textOrNull(widgetData, "percent", suffix) ?: "",
        )
        views.setTextColor(R.id.widget_percent, color)
        val ratio = (widgetData.getInt(key("ratio", suffix), 0)).coerceIn(0, 100)
        views.setImageViewBitmap(R.id.widget_bar, drawBar(color, titleColor, ratio))
        return true
    }

    /** Renders the budget progress bar (rounded track + colored fill). */
    private fun drawBar(
        color: Int,
        titleColor: Int,
        ratio: Int,
    ): android.graphics.Bitmap {
        val w = 1000
        val h = 64
        val dark = (titleColor and 0xFFFFFF) == 0xFFFFFF
        val bmp = android.graphics.Bitmap.createBitmap(w, h, android.graphics.Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bmp)
        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        val radius = h / 2f
        // Track.
        paint.color = if (dark) 0x26FFFFFF.toInt() else 0x1F000000.toInt()
        canvas.drawRoundRect(
            android.graphics.RectF(0f, 0f, w.toFloat(), h.toFloat()),
            radius, radius, paint,
        )
        // Fill.
        val fillW = (w.toLong() * ratio / 100).toInt()
        if (fillW > 0) {
            paint.color = color
            canvas.drawRoundRect(
                android.graphics.RectF(0f, 0f, fillW.toFloat(), h.toFloat()),
                radius, radius, paint,
            )
        }
        return bmp
    }
}
