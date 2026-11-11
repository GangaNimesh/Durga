package com.arun.durga.durga

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.arun.durga.durga/widget"
    }

    private var initialRoute: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Ensure Fake Call or Voice screens can show over the lock screen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        initialRoute = extractRoute(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialRoute" -> {
                    val route = initialRoute
                    initialRoute = null
                    result.success(route)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }

        val route = extractRoute(intent)
        if (route != null) {
            flutterEngine?.let { engine ->
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("onWidgetRoute", route)
            }
        }
    }

    private fun extractRoute(intent: Intent?): String? {
        if (intent == null) return null
        val routeExtra = intent.getStringExtra("route")
        if (!routeExtra.isNullOrEmpty()) return routeExtra

        val data = intent.data ?: return null
        val path = data.path?.trim()
        if (!path.isNullOrEmpty() && path != "/") {
            return if (path.startsWith("/")) path else "/$path"
        }
        val host = data.host?.trim()
        if (!host.isNullOrEmpty() && host != "widget") {
            return "/$host"
        }
        return null
    }
}
