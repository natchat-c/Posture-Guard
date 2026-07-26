import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'alert_mute_service.dart';

@pragma('vm:entry-point')
Future<void> handlePostureNotificationAction(
  NotificationResponse response,
) async {
  DartPluginRegistrant.ensureInitialized();
  if (response.actionId != PostureNotificationService.mute15MinutesActionId) {
    return;
  }
  await AlertMuteController().muteFor();
  await PostureNotificationService.cancelPostureAlert();
}

class PostureNotificationService {
  PostureNotificationService._();

  static const int foregroundServiceNotificationId = 41001;
  static const int postureAlertNotificationId = 41002;
  static const String postureAlertChannelId = 'posture_alerts_v2';
  static const String postureAlertChannelName = 'Posture Alerts';
  static const String mute15MinutesActionId = 'mute_15_minutes';
  static const List<AndroidNotificationAction> postureAlertActions = [
    AndroidNotificationAction(
      mute15MinutesActionId,
      'Mute for 15 min',
      showsUserInterface: false,
      cancelNotification: true,
    ),
  ];

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: handlePostureNotificationAction,
      onDidReceiveBackgroundNotificationResponse:
          handlePostureNotificationAction,
    );

    const channel = AndroidNotificationChannel(
      postureAlertChannelId,
      postureAlertChannelName,
      description: 'Sound and vibration alerts for sustained poor posture.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  static Future<void> showPostureAlert() async {
    await initialize();

    final androidDetails = AndroidNotificationDetails(
      postureAlertChannelId,
      postureAlertChannelName,
      channelDescription:
          'Sound and vibration alerts for sustained poor posture.',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 700, 250, 700, 250, 1000]),
      onlyAlertOnce: false,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      actions: postureAlertActions,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    await _plugin.show(
      id: postureAlertNotificationId,
      title: 'Check your posture',
      body:
          'Your phone angle suggests poor posture. Adjust your position or mute alerts temporarily.',
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
    );
  }

  static Future<void> cancelPostureAlert() async {
    await initialize();
    await _plugin.cancel(id: postureAlertNotificationId);
  }
}
