import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

@pragma('vm:entry-point')
void soloTripNotificationTapBackground(NotificationResponse response) {
  debugPrint('[SoloTrip BG] Notification response: actionId=${response.actionId}, payload=${response.payload}');
  if (response.actionId == 'confirm' || response.payload == 'confirm_checkin') {
    SoloTripService.instance.confirmCheckin();
  } else if (response.actionId == 'end_trip' || response.payload == 'end_trip') {
    SoloTripService.instance.endSession();
  }
}

class SoloTripService extends ChangeNotifier {
  SoloTripService._();
  static final SoloTripService instance = SoloTripService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  static const String _prefSessionIdKey = 'active_solo_trip_session_id';
  static const String _prefIntervalKey = 'active_solo_trip_interval';

  String? _activeSessionId;
  int _intervalMinutes = 15;
  DateTime? _startedAt;
  DateTime? _lastCheckinAt;
  Timer? _locationTimer;
  Timer? _checkinTimer;
  
  bool get isActive => _activeSessionId != null;
  String? get activeSessionId => _activeSessionId;
  int get intervalMinutes => _intervalMinutes;
  DateTime? get startedAt => _startedAt;
  DateTime? get lastCheckinAt => _lastCheckinAt;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: soloTripNotificationTapBackground,
    );

    // Request notification permission for Android 13+
    await requestNotificationPermission();

    // Check if there was an active session before app restart
    await _restoreSession();
  }

  Future<bool> requestNotificationPermission() async {
    final android = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      debugPrint('[SoloTripService] Notification permission granted: $granted');
      return granted ?? false;
    }
    return true;
  }

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSessionId = prefs.getString(_prefSessionIdKey);
      final savedInterval = prefs.getInt(_prefIntervalKey) ?? 15;
      
      if (savedSessionId != null && savedSessionId.isNotEmpty) {
        _activeSessionId = savedSessionId;
        _intervalMinutes = savedInterval;
        _startedAt = DateTime.now();
        _startBackgroundTasks(savedInterval);
        notifyListeners();
        debugPrint('[SoloTripService] Restored active session from prefs: $savedSessionId');
        return;
      }

      // Check remote Supabase active session
      final remoteSession = await SupabaseService.instance.getActiveSoloTrip();
      if (remoteSession != null) {
        _activeSessionId = remoteSession['id'];
        _intervalMinutes = remoteSession['interval_minutes'] as int? ?? 15;
        _startedAt = DateTime.tryParse(remoteSession['started_at'] ?? '') ?? DateTime.now();
        await prefs.setString(_prefSessionIdKey, _activeSessionId!);
        await prefs.setInt(_prefIntervalKey, _intervalMinutes);
        _startBackgroundTasks(_intervalMinutes);
        notifyListeners();
        debugPrint('[SoloTripService] Restored active session from Supabase: $_activeSessionId');
      }
    } catch (e) {
      debugPrint('[SoloTripService] Failed to restore session: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) async {
    debugPrint('[SoloTrip] Notification tapped: actionId=${response.actionId}, payload=${response.payload}');
    if (response.actionId == 'confirm' || response.payload == 'confirm_checkin') {
      await confirmCheckin();
    } else if (response.actionId == 'end_trip' || response.payload == 'end_trip') {
      await endSession();
    }
  }

  Future<void> startSession({
    required int intervalMinutes,
    required int gracePeriodMinutes,
    required String notifyMethod,
    required List<String> alertContactIds,
  }) async {
    // Ensure notification permissions are available
    await requestNotificationPermission();

    // 1. Fetch current location
    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // 2. Start session in Supabase
    final session = await SupabaseService.instance.startSoloTripSession(
      intervalMinutes: intervalMinutes,
      gracePeriodMinutes: gracePeriodMinutes,
      notifyMethod: notifyMethod,
      alertContactIds: alertContactIds,
    );

    _activeSessionId = session['id'];
    _intervalMinutes = intervalMinutes;
    _startedAt = DateTime.now();
    _lastCheckinAt = DateTime.now();

    // Persist in local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSessionIdKey, _activeSessionId!);
    await prefs.setInt(_prefIntervalKey, intervalMinutes);

    // 3. Show ongoing status notification
    await _showOngoingStatusNotification(intervalMinutes);

    // 4. Start background sync & timers
    _startBackgroundTasks(intervalMinutes);
    
    // Initial location push
    await SupabaseService.instance.upsertLiveLocation(
      lat: pos.latitude, 
      lng: pos.longitude, 
      source: 'solo_trip',
    );

    notifyListeners();
  }

  void _startBackgroundTasks(int intervalMinutes) {
    // Background location sync every 60 seconds
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
      try {
        Position p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        await SupabaseService.instance.upsertLiveLocation(
          lat: p.latitude, 
          lng: p.longitude, 
          source: 'solo_trip',
        );
      } catch (e) {
        debugPrint('[SoloTripService] Background location sync error: $e');
      }
    });

    // Local check-in reminder
    _checkinTimer?.cancel();
    _checkinTimer = Timer.periodic(Duration(minutes: intervalMinutes), (timer) {
      showCheckinNotification();
    });
  }

  Future<void> _showOngoingStatusNotification(int intervalMinutes) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'solo_trip_status',
      'Solo Trip Protection',
      channelDescription: 'Shows active Solo Trip status',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      1000,
      '🛡️ Solo Trip Active',
      'Durga is monitoring your journey. Checking in every $intervalMinutes min.',
      details,
      payload: 'active_status',
    );
  }

  /// Displays the Check-in notification with two action buttons:
  /// 1. "I am safe" (confirms check-in)
  /// 2. "Stop Trip" (ends the trip immediately)
  Future<void> showCheckinNotification({bool isDebug = false}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'solo_trip_checkin',
      'Safety Check-in',
      channelDescription: 'Time to confirm you are safe during Solo Trip',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Safety check-in required',
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'confirm',
          'I am safe',
          cancelNotification: true,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'end_trip',
          'Stop Trip',
          cancelNotification: true,
          showsUserInterface: true,
        ),
      ],
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      isDebug ? 999 : 1001,
      isDebug ? '⚠️ [DEBUG] Safety Check-in Test' : '🚨 Safety Check-in Required',
      isDebug 
          ? 'Notification Test: Tap "I am safe" to confirm or "Stop Trip" to end.'
          : 'Please confirm your safety. Grace period has started.',
      details,
      payload: isDebug ? 'confirm_checkin' : 'confirm_checkin',
    );
  }

  /// Triggers an immediate test check-in notification for debugging
  Future<void> triggerDebugCheckinNotification() async {
    await requestNotificationPermission();
    await showCheckinNotification(isDebug: true);
  }

  Future<void> confirmCheckin() async {
    debugPrint('[SoloTripService] Confirming checkin...');
    _lastCheckinAt = DateTime.now();
    try {
      await _notificationsPlugin.cancel(1001);
      await _notificationsPlugin.cancel(999);
      
      if (_activeSessionId != null) {
        Position p = await Geolocator.getCurrentPosition();
        await SupabaseService.instance.confirmCheckin(
          sessionId: _activeSessionId!,
          lat: p.latitude,
          lng: p.longitude,
        );
        debugPrint("[SoloTripService] Check-in confirmed in Supabase.");
      }
    } catch (e) {
      debugPrint("[SoloTripService] Failed to confirm checkin: $e");
    }
    notifyListeners();
  }

  Future<void> endSession() async {
    debugPrint('[SoloTripService] Ending Solo Trip session...');
    if (_activeSessionId != null) {
      try {
        await SupabaseService.instance.endSoloTripSession(_activeSessionId!);
      } catch (e) {
        debugPrint('[SoloTripService] Error ending session in Supabase: $e');
      }
      _activeSessionId = null;
    }
    _locationTimer?.cancel();
    _checkinTimer?.cancel();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefSessionIdKey);
    await prefs.remove(_prefIntervalKey);

    await _notificationsPlugin.cancel(1000); // status
    await _notificationsPlugin.cancel(1001); // checkin
    await _notificationsPlugin.cancel(999);  // debug
    
    notifyListeners();
  }
}
