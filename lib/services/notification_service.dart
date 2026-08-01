import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../l10n/locale_controller.dart';
import 'alert_mute_service.dart';
import 'preferences_service.dart';

@pragma('vm:entry-point')
Future<void> handlePostureNotificationAction(
  NotificationResponse response,
) async {
  DartPluginRegistrant.ensureInitialized();
  await applyPostureNotificationAction(response.actionId);
}

Future<bool> applyPostureNotificationAction(
  String? actionId, {
  AlertMuteController? muteController,
  Future<void> Function()? cancelNotification,
}) async {
  final duration = switch (actionId) {
    PostureNotificationService.mute15MinutesActionId =>
      postureAlertMute15MinutesDuration,
    PostureNotificationService.mute1HourActionId =>
      postureAlertMute1HourDuration,
    _ => null,
  };
  if (duration == null) return false;

  await (muteController ?? AlertMuteController()).muteFor(duration);
  await (cancelNotification ?? PostureNotificationService.cancelPostureAlert)();
  return true;
}

class PostureNotificationContent {
  const PostureNotificationContent({
    required this.title,
    required this.body,
    required this.mute15MinutesLabel,
    required this.mute1HourLabel,
    required this.channelId,
  });

  final String title;
  final String body;
  final String mute15MinutesLabel;
  final String mute1HourLabel;
  final String channelId;
}

class PostureNotificationService {
  PostureNotificationService._();

  static const int foregroundServiceNotificationId = 41001;
  static const int postureAlertNotificationId = 41002;
  static const String postureAlertChannelId = 'posture_alerts_v2';
  static const String postureAlertChannelName = 'Posture Alerts';
  static const String mute15MinutesActionId = 'mute_15_minutes';
  static const String mute1HourActionId = 'mute_1_hour';
  static const List<AndroidNotificationAction> postureAlertActions = [
    AndroidNotificationAction(
      mute15MinutesActionId,
      'Mute 15 min',
      showsUserInterface: false,
      cancelNotification: true,
    ),
    AndroidNotificationAction(
      mute1HourActionId,
      'Mute 1 hour',
      showsUserInterface: false,
      cancelNotification: true,
    ),
  ];

  static List<AndroidNotificationAction> postureAlertActionsForLanguage(
    String? languageCode,
  ) {
    final content = contentForLanguage(languageCode);
    return [
      AndroidNotificationAction(
        mute15MinutesActionId,
        content.mute15MinutesLabel,
        showsUserInterface: false,
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        mute1HourActionId,
        content.mute1HourLabel,
        showsUserInterface: false,
        cancelNotification: true,
      ),
    ];
  }

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static PostureNotificationContent contentForLanguage(String? languageCode) {
    final l10n = localizationsForLanguage(languageCode);
    return PostureNotificationContent(
      title: l10n.postureNotificationTitle,
      body: l10n.postureNotificationBody,
      mute15MinutesLabel: l10n.mute15Minutes,
      mute1HourLabel: l10n.mute1Hour,
      channelId: postureAlertChannelId,
    );
  }

  static Future<PostureNotificationContent> loadContent({
    LanguagePreferences? languagePreferences,
  }) async {
    final code = await (languagePreferences ?? LanguagePreferences()).load();
    return contentForLanguage(code);
  }

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
      description: 'Posture reminders from Posture Guard',
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
    final languageCode = await LanguagePreferences().load();
    final content = contentForLanguage(languageCode);
    final l10n = localizationsForLanguage(languageCode);

    final androidDetails = AndroidNotificationDetails(
      postureAlertChannelId,
      postureAlertChannelName,
      channelDescription: l10n.notificationChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 700, 250, 700, 250, 1000]),
      onlyAlertOnce: false,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      actions: postureAlertActionsForLanguage(languageCode),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    await _plugin.show(
      id: postureAlertNotificationId,
      title: content.title,
      body: content.body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
    );
  }

  static Future<({String title, String body})> foregroundText({
    required bool screenInteractive,
    LanguagePreferences? languagePreferences,
  }) async {
    final code = await (languagePreferences ?? LanguagePreferences()).load();
    return foregroundTextForLanguage(
      languageCode: code,
      screenInteractive: screenInteractive,
    );
  }

  static ({String title, String body}) foregroundTextForLanguage({
    required String? languageCode,
    required bool screenInteractive,
  }) {
    final l10n = localizationsForLanguage(languageCode);
    return (
      title: l10n.foregroundTitle,
      body: screenInteractive
          ? l10n.foregroundMonitoring
          : l10n.foregroundPaused,
    );
  }

  static Future<void> cancelPostureAlert() async {
    await initialize();
    await _plugin.cancel(id: postureAlertNotificationId);
  }
}
