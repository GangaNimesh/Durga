import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

/// Bridge between the Flutter app and the native Android home screen widget.
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const MethodChannel _platformChannel =
      MethodChannel('com.arun.durga.durga/widget');

  /// Global navigator key to push screens from widget taps.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Broadcasts widget actions (/record, /voice) to active screens.
  static final ValueNotifier<String?> widgetActionNotifier =
      ValueNotifier<String?>(null);

  /// Pending route from a widget tap that cold-started the app.
  String? pendingRoute;

  Future<void> init() async {
    HomeWidget.registerInteractivityCallback(_backgroundCallback);

    // 1. Native platform channel listener (from MainActivity onNewIntent)
    _platformChannel.setMethodCallHandler((call) async {
      debugPrint('[WidgetService] Platform channel method: ${call.method}');
      if (call.method == 'onWidgetRoute') {
        final route = call.arguments as String?;
        debugPrint('[WidgetService] Platform channel received route: $route');
        if (route != null && route.isNotEmpty) {
          handleAction(route);
        }
      }
    });

    // 2. Cold-start check via platform channel
    try {
      final initialRoute =
          await _platformChannel.invokeMethod<String>('getInitialRoute');
      if (initialRoute != null && initialRoute.isNotEmpty) {
        debugPrint('[WidgetService] Cold start from platform channel: $initialRoute');
        pendingRoute = initialRoute;
      }
    } catch (e) {
      debugPrint('[WidgetService] getInitialRoute error: $e');
    }

    // 3. Cold-start check via home_widget plugin
    if (pendingRoute == null) {
      try {
        final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
        if (uri != null) {
          debugPrint('[WidgetService] Cold start from widget URI: $uri');
          pendingRoute = _routeFromUri(uri);
        }
      } catch (e) {
        debugPrint('[WidgetService] initiallyLaunchedFromHomeWidget error: $e');
      }
    }

    // 4. Listen for widget clicks while app is in memory via home_widget plugin
    HomeWidget.widgetClicked.listen((uri) {
      debugPrint('[WidgetService] widgetClicked URI: $uri');
      if (uri == null) return;
      final route = _routeFromUri(uri);
      if (route != null) {
        handleAction(route);
      }
    });

    // 5. Sync widget recording state on startup (reset stale is_recording flag)
    try {
      await updateWidgetData({'is_recording': false});
    } catch (e) {
      debugPrint('[WidgetService] Widget state sync error: $e');
    }
  }

  /// Extracts a normalized route from various URI formats.
  static String? _routeFromUri(Uri uri) {
    debugPrint('[WidgetService] Parsing URI: $uri (path: "${uri.path}", host: "${uri.host}")');
    final path = uri.path.trim();
    if (path.isNotEmpty && path != '/') {
      return path.startsWith('/') ? path : '/$path';
    }
    final host = uri.host.trim();
    if (host.isNotEmpty && host != 'widget') {
      return '/$host';
    }
    return null;
  }

  /// Dispatches the widget route to either navigator or active listeners.
  void handleAction(String route) {
    debugPrint('[WidgetService] Handling widget action: $route');
    if (route == '/fake-call') {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState?.pushNamed('/fake-call');
      } else {
        pendingRoute = route;
      }
    } else if (route == '/record' || route == '/voice') {
      // Notify active home screen to execute without pushing duplicate screens
      widgetActionNotifier.value = null; // reset to re-trigger if same action
      widgetActionNotifier.value = route;

      // If navigator has no active route (e.g. app just opened), save as pending
      if (navigatorKey.currentState == null) {
        pendingRoute = route;
      }
    }
  }

  /// Update shared data and refresh native widget views.
  Future<void> updateWidgetData(Map<String, dynamic> data) async {
    try {
      for (final entry in data.entries) {
        if (entry.value is bool) {
          await HomeWidget.saveWidgetData<bool>(entry.key, entry.value as bool);
        } else {
          await HomeWidget.saveWidgetData<String>(entry.key, entry.value.toString());
        }
      }
      await HomeWidget.updateWidget(
        androidName: 'DurgaWidgetProvider',
        qualifiedAndroidName: 'com.arun.durga.durga.DurgaWidgetProvider',
      );
    } catch (e) {
      debugPrint('[WidgetService] updateWidgetData error: $e');
    }
  }
}

@pragma('vm:entry-point')
Future<void> _backgroundCallback(Uri? uri) async {
  debugPrint('[WidgetService BG] Callback with URI: $uri');
}
