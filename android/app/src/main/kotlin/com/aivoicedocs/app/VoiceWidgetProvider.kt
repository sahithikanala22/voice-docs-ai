package com.aivoicedocs.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget that jumps straight into recording — tapping it opens
 * the app on the Today tab and starts listening immediately, instead of
 * opening the app and needing a second tap on the mic button.
 */
class VoiceWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    for (widgetId in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.voice_widget_layout)
      val pendingIntent =
          HomeWidgetLaunchIntent.getActivity(
              context,
              MainActivity::class.java,
              Uri.parse("aivoicedocs://record"),
          )
      views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
