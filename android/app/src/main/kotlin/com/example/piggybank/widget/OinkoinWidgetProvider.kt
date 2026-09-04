package com.example.piggybank.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import com.example.piggybank.R
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

/**
 * Base for Oinkoin home screen widgets. The UI is rendered by Flutter to a
 * bitmap ([HomeWidgetService]) and stored under an image key; the provider
 * only shows that image and opens the app on tap. [imageKeyForInstance]
 * lets the budget provider serve a different image per pinned instance.
 */
abstract class OinkoinWidgetProvider : HomeWidgetProvider() {

    protected abstract fun imageKeyForInstance(
        context: Context,
        appWidgetId: Int,
    ): String?

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences,
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.oinkoin_image_widget)
            val imageKey = imageKeyForInstance(context, appWidgetId)
            val imagePath = imageKey?.let { widgetData.getString(it, null) }
            val imageFile = imagePath?.let { File(it) }
            if (imageFile != null && imageFile.exists()) {
                val bitmap = BitmapFactory.decodeFile(imageFile.absolutePath)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_image, bitmap)
                    views.setViewVisibility(R.id.widget_image, View.VISIBLE)
                }
            }
            val launchIntent =
                context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_image, pendingIntent)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
