package com.arun.durga.durga

import android.app.ActivityOptions
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Durga Safety Widget — provides quick access to SOS, Fake Call, Record/Stop Record,
 * and Voice commands directly from the Android home screen and lock screen.
 */
class DurgaWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "DurgaWidgetProvider"
        const val ACTION_SOS = "com.arun.durga.durga.ACTION_SOS"
        const val ACTION_FAKE_CALL = "com.arun.durga.durga.ACTION_FAKE_CALL"
        const val ACTION_RECORD = "com.arun.durga.durga.ACTION_RECORD"
        const val ACTION_VOICE = "com.arun.durga.durga.ACTION_VOICE"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        try {
            when (intent.action) {
                ACTION_SOS -> {
                    val callIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:100")).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(callIntent)
                }
                ACTION_FAKE_CALL -> {
                    launchAppWithRoute(context, "/fake-call")
                }
                ACTION_RECORD -> {
                    launchAppWithRoute(context, "/record")
                }
                ACTION_VOICE -> {
                    launchAppWithRoute(context, "/voice")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in onReceive: ${e.message}", e)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            val views = RemoteViews(context.packageName, R.layout.durga_widget)

            // 1. SOS Button -> Direct dialer intent to 100
            val dialIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:100")).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val pendingDial = createActivityPendingIntentForCustom(context, dialIntent, 100)
            views.setOnClickPendingIntent(R.id.btn_sos, pendingDial)
            views.setOnClickPendingIntent(R.id.btn_sos_icon, pendingDial)
            views.setOnClickPendingIntent(R.id.btn_sos_text, pendingDial)

            // 2. Fake Call Button
            val pendingFakeCall = createActivityPendingIntent(context, "/fake-call", 101)
            views.setOnClickPendingIntent(R.id.btn_fake_call, pendingFakeCall)
            views.setOnClickPendingIntent(R.id.btn_fake_call_bg, pendingFakeCall)
            views.setOnClickPendingIntent(R.id.btn_fake_call_icon, pendingFakeCall)
            views.setOnClickPendingIntent(R.id.btn_fake_call_label, pendingFakeCall)

            // 3. Dynamic Record / Stop Record Button (safely read value without ClassCastException)
            val isRecording = try {
                val allData = HomeWidgetPlugin.getData(context).all
                val raw = allData["is_recording"]
                when (raw) {
                    is Boolean -> raw
                    is String -> raw.equals("true", ignoreCase = true)
                    is Number -> raw.toInt() != 0
                    else -> false
                }
            } catch (e: Exception) {
                Log.w(TAG, "Could not read is_recording: ${e.message}")
                false
            }

            if (isRecording) {
                views.setImageViewResource(R.id.btn_record_icon, R.drawable.ic_stop)
                views.setTextViewText(R.id.btn_record_label, "Stop")
                views.setTextColor(R.id.btn_record_label, Color.parseColor("#FF5252"))
                views.setInt(R.id.btn_record_bg, "setBackgroundResource", R.drawable.action_button_bg_recording)
            } else {
                views.setImageViewResource(R.id.btn_record_icon, R.drawable.ic_mic)
                views.setTextViewText(R.id.btn_record_label, "Record")
                views.setTextColor(R.id.btn_record_label, Color.parseColor("#99FFFFFF"))
                views.setInt(R.id.btn_record_bg, "setBackgroundResource", R.drawable.action_button_bg)
            }

            val pendingRecord = createActivityPendingIntent(context, "/record", 102)
            views.setOnClickPendingIntent(R.id.btn_record, pendingRecord)
            views.setOnClickPendingIntent(R.id.btn_record_bg, pendingRecord)
            views.setOnClickPendingIntent(R.id.btn_record_icon, pendingRecord)
            views.setOnClickPendingIntent(R.id.btn_record_label, pendingRecord)

            // 4. Voice Button
            val pendingVoice = createActivityPendingIntent(context, "/voice", 103)
            views.setOnClickPendingIntent(R.id.btn_voice, pendingVoice)
            views.setOnClickPendingIntent(R.id.btn_voice_bg, pendingVoice)
            views.setOnClickPendingIntent(R.id.btn_voice_icon, pendingVoice)
            views.setOnClickPendingIntent(R.id.btn_voice_label, pendingVoice)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (e: Exception) {
            Log.e(TAG, "Error updating app widget: ${e.message}", e)
        }
    }

    private fun createActivityPendingIntent(
        context: Context,
        route: String,
        requestCode: Int
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            data = Uri.parse("durgaWidget://widget$route")
            putExtra("route", route)
        }
        return createActivityPendingIntentForCustom(context, intent, requestCode)
    }

    private fun createActivityPendingIntentForCustom(
        context: Context,
        intent: Intent,
        requestCode: Int
    ): PendingIntent {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }

        val optionsBundle = getBackgroundActivityStartOptions()
        return if (optionsBundle != null) {
            PendingIntent.getActivity(context, requestCode, intent, flags, optionsBundle)
        } else {
            PendingIntent.getActivity(context, requestCode, intent, flags)
        }
    }

    private fun getBackgroundActivityStartOptions(): Bundle? {
        if (Build.VERSION.SDK_INT < 34) return null
        val options = ActivityOptions.makeBasic()
        if (Build.VERSION.SDK_INT >= 35) {
            options.setPendingIntentCreatorBackgroundActivityStartMode(
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
            )
        } else {
            options.pendingIntentBackgroundActivityStartMode =
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
        }
        return options.toBundle()
    }

    private fun launchAppWithRoute(context: Context, route: String) {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("route", route)
            data = Uri.parse("durgaWidget://widget$route")
        }
        context.startActivity(intent)
    }
}
