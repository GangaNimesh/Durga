import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'silent_recorder.dart';
import 'widget_service.dart';

/// Service managing the persistent lock screen / notification shade widget.
///
/// Provides instant access to:
///  - SOS (direct 100 call)
///  - Fake Call (opens FakeCallScreen)
///  - Silent Record (toggle audio recording)
///  - Voice (opens Voice Command overlay)
class SafetyNotificationService {
  SafetyNotificationService._();
  static final SafetyNotificationService instance = SafetyNotificationService._();

  static const String _prefEnabledKey = 'pref_lockscreen_safety_notification_enabled';
  static const int notificationId = 9001;
  static const String channelId = 'durga_pocket_guard_quiet';
  static const String channelName = 'Durga Pocket Guard';
  static const String channelDesc =
      'Instant access to emergency tools right from your lock screen.';

  // Action IDs
  static const String actionSos = 'safety_action_sos';
  static const String actionFakeCall = 'safety_action_fake_call';
  static const String actionRecord = 'safety_action_record';
  static const String actionVoice = 'safety_action_voice';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isEnabled = true;
  bool get isEnabled => _isEnabled;

  bool? _lastIsRecording;
  bool _hasShownInitialNotification = false;

  /// Initialize and show persistent lock screen notification if enabled.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_prefEnabledKey) ?? true;

      // Clean up old noisy channel if it exists
      final android = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.deleteNotificationChannel('durga_lockscreen_safety_actions');

      if (_isEnabled) {
        await showLockScreenNotification(force: true);
      }
    } catch (e) {
      debugPrint('[SafetyNotificationService] init error: $e');
    }
  }

  /// Toggle setting and update notification display.
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabledKey, enabled);

    if (enabled) {
      await showLockScreenNotification(force: true);
    } else {
      await cancelLockScreenNotification();
    }
  }

  /// Displays the persistent lock screen notification with 4 action buttons.
  Future<void> showLockScreenNotification({bool force = false}) async {
    if (!_isEnabled) return;

    try {
      final isRec = SilentRecorder.instance.isRecording;
      if (!force && _hasShownInitialNotification && _lastIsRecording == isRec) {
        // State unchanged — avoid re-posting notification repeatedly
        return;
      }
      _hasShownInitialNotification = true;
      _lastIsRecording = isRec;

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        silent: true,
        playSound: false,
        enableVibration: false,
        onlyAlertOnce: true,
        channelAction: AndroidNotificationChannelAction.createIfNotExists,
        additionalFlags: Int32List.fromList(<int>[32]), // FLAG_NO_CLEAR (32) prevents user dismissal
        showWhen: false,
        visibility: NotificationVisibility.public,
        color: const Color(0xFFE8735A), // Coral accent
        category: AndroidNotificationCategory.status,
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            actionSos,
            'SOS',
            showsUserInterface: true,
            cancelNotification: false,
          ),
          const AndroidNotificationAction(
            actionFakeCall,
            'Fake Call',
            showsUserInterface: true,
            cancelNotification: false,
          ),
          AndroidNotificationAction(
            actionRecord,
            isRec ? 'Stop' : 'Record',
            showsUserInterface: false,
            cancelNotification: false,
          ),
          const AndroidNotificationAction(
            actionVoice,
            'Voice',
            showsUserInterface: true,
            cancelNotification: false,
          ),
        ],
      );

      final details = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        notificationId,
        'Durga Pocket Guard',
        isRec ? 'Discreet recording active · Tap to stop' : 'Got your back · Quick tools ready',
        details,
        payload: 'safety_widget',
      );
      debugPrint('[SafetyNotificationService] Lock screen notification displayed (quiet & persistent)');
    } catch (e) {
      debugPrint('[SafetyNotificationService] Error showing notification: $e');
    }
  }

  /// Cancels the persistent lock screen notification.
  Future<void> cancelLockScreenNotification() async {
    try {
      await _notificationsPlugin.cancel(notificationId);
      debugPrint('[SafetyNotificationService] Lock screen notification cancelled');
    } catch (e) {
      debugPrint('[SafetyNotificationService] Error cancelling notification: $e');
    }
  }

  /// Handle an action triggered from the notification.
  Future<void> handleAction(String actionId) async {
    debugPrint('[SafetyNotificationService] Handling action: $actionId');
    switch (actionId) {
      case actionSos:
        await _triggerSos();
        break;
      case actionFakeCall:
        _navigateTo('/fake-call');
        break;
      case actionRecord:
        await _toggleRecord();
        break;
      case actionVoice:
        _navigateTo('/voice');
        break;
      default:
        break;
    }
    // Re-assert persistent lock screen notification display
    if (_isEnabled && actionId != actionRecord) {
      await showLockScreenNotification();
    }
  }

  Future<void> _triggerSos() async {
    final uri = Uri.parse('tel:100');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _navigateTo(String route) {
    final nav = WidgetService.instance.navigatorKey.currentState;
    if (nav != null) {
      nav.pushNamed(route);
    } else {
      WidgetService.instance.pendingRoute = route;
    }
  }

  Future<void> _toggleRecord() async {
    if (SilentRecorder.instance.isRecording) {
      await SilentRecorder.instance.stopRecording();
    } else {
      await SilentRecorder.instance.startRecording();
    }
    // Update notification to reflect recording status
    if (_isEnabled) {
      await showLockScreenNotification();
    }
  }
}
