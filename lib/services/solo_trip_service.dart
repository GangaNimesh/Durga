import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import 'supabase_service.dart';

class SoloTripService {
  SoloTripService._();
  static final SoloTripService instance = SoloTripService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  String? _activeSessionId;
  Timer? _locationTimer;
  Timer? _checkinTimer;
  
  bool get isActive => _activeSessionId != null;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  void _onNotificationTapped(NotificationResponse response) async {
    if (response.payload == 'confirm_checkin' && _activeSessionId != null) {
      await confirmCheckin();
    }
  }

  Future<void> startSession({
    required int intervalMinutes,
    required int gracePeriodMinutes,
    required String notifyMethod,
    required List<String> alertContactIds,
  }) async {
    // 1. Fetch current location
    Position pos = await Geolocator.getCurrentPosition();

    // 2. Start session in Supabase
    final session = await SupabaseService.instance.startSoloTripSession(
      intervalMinutes: intervalMinutes,
      gracePeriodMinutes: gracePeriodMinutes,
      notifyMethod: notifyMethod,
      alertContactIds: alertContactIds,
    );

    _activeSessionId = session['id'];

    // 3. Start background location sync every 60 seconds
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
      Position p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await SupabaseService.instance.upsertLiveLocation(
        lat: p.latitude, 
        lng: p.longitude, 
        source: 'solo_trip',
      );
    });

    // 4. Start local check-in reminders (slightly before the server deadline)
    _checkinTimer?.cancel();
    _checkinTimer = Timer.periodic(Duration(minutes: intervalMinutes), (timer) {
      _showCheckinNotification();
    });
    
    // Initial location push
    await SupabaseService.instance.upsertLiveLocation(
      lat: pos.latitude, 
      lng: pos.longitude, 
      source: 'solo_trip',
    );
  }

  Future<void> _showCheckinNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'solo_trip_checkin',
      'Safety Check-in',
      channelDescription: 'Time to confirm you are safe',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('confirm', 'I am safe', cancelNotification: true),
      ],
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      0,
      'Safety Check-in Required',
      'Tap here to confirm you are safe. Grace period has started.',
      details,
      payload: 'confirm_checkin',
    );
  }

  Future<void> confirmCheckin() async {
    if (_activeSessionId == null) return;
    try {
      Position p = await Geolocator.getCurrentPosition();
      await SupabaseService.instance.confirmCheckin(
        sessionId: _activeSessionId!,
        lat: p.latitude,
        lng: p.longitude,
      );
      debugPrint("Check-in confirmed successfully.");
    } catch (e) {
      debugPrint("Failed to confirm checkin: $e");
    }
  }

  Future<void> endSession() async {
    if (_activeSessionId != null) {
      await SupabaseService.instance.endSoloTripSession(_activeSessionId!);
      _activeSessionId = null;
    }
    _locationTimer?.cancel();
    _checkinTimer?.cancel();
    await _notificationsPlugin.cancelAll();
  }
}
