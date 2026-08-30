import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/l10n/app_localizations.dart';
import 'package:postureguard/models/app_settings.dart';
import 'package:postureguard/models/calibration.dart';
import 'package:postureguard/pages/settings_page.dart';
import 'package:postureguard/services/alert_mute_service.dart';
import 'package:postureguard/services/camera_privacy_service.dart';
import 'package:postureguard/services/device_screen_time_service.dart';
import 'package:postureguard/services/monitoring_service.dart';
import 'package:postureguard/services/preferences_service.dart';
import 'package:postureguard/widgets/coach_mark_overlay.dart';
import 'package:postureguard/widgets/no_stretch_scroll_behavior.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FakeSettingsStore implements SettingsStore {
  _FakeSettingsStore(
    this.settings, {
    this.saveResult = const SettingsSaveResult(
      savedLocally: true,
      savedToFirebase: true,
    ),
  });

  AppSettings settings;
  SettingsSaveResult saveResult;
  AppSettings? savedSettings;

  @override
  Future<SettingsLoadResult> load() async {
    return SettingsLoadResult(settings: settings);
  }

  @override
  Future<SettingsSaveResult> save(AppSettings value) async {
    savedSettings = value;
    settings = value;
    return saveResult;
  }
}

class _FakeScreenTimeProvider extends DeviceScreenTimeProvider {
  bool supported = true;
  bool hasAccess = false;
  int settingsOpens = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> hasUsageAccess() async => hasAccess;

  @override
  Future<bool> openUsageAccessSettings() async {
    settingsOpens++;
    return supported;
  }

  @override
  Future<int?> getScreenTimeSeconds({
    required DateTime start,
    required DateTime end,
  }) async {
    return hasAccess ? 100 : null;
  }
}

class _FakeMuteStore implements AlertMuteStore {
  int? value;

  @override
  Future<int?> readMutedUntilEpochMs() async => value;

  @override
  Future<void> writeMutedUntilEpochMs(int? epochMs) async => value = epochMs;
}

Widget _settingsApp(
  _FakeSettingsStore store, {
  Future<bool> Function()? loadMonitoringState,
  Future<MonitoringControlResult> Function(bool enabled)?
  onMonitoringEnabledChanged,
  Future<void> Function(AppSettings settings)? onSettingsSaved,
  Future<bool> Function()? onCalibrateNeutral,
  DeviceScreenTimeProvider? screenTimeProvider,
  AlertMuteController? alertMuteController,
  VoidCallback? onAlertMuteChanged,
  Calibration? initialCalibration,
  Calibration? Function()? currentCalibration,
  bool initialHasCalibration = false,
  bool showGuidedTour = false,
  Locale locale = const Locale('en'),
  Future<NotificationPermission> Function()? loadNotificationPermission,
  Future<NotificationPermission> Function()? requestNotificationPermission,
  CameraAssistPermissionCoordinator? cameraCoordinator,
  Future<void> Function(bool enabled)? onCameraAssistChanged,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    scrollBehavior: const NoStretchScrollBehavior(),
    home: Settings(
      store: store,
      onCalibrateNeutral: onCalibrateNeutral ?? () async => true,
      loadMonitoringState: loadMonitoringState,
      onMonitoringEnabledChanged: onMonitoringEnabledChanged,
      onSettingsSaved: onSettingsSaved,
      screenTimeProvider: screenTimeProvider,
      alertMuteController:
          alertMuteController ??
          AlertMuteController(
            store: _FakeMuteStore(),
            clock: () => DateTime(2026, 7, 26, 14, 30),
          ),
      onAlertMuteChanged: onAlertMuteChanged,
      initialCalibration: initialCalibration,
      currentCalibration: currentCalibration,
      initialHasCalibration: initialHasCalibration,
      showGuidedTour: showGuidedTour,
      loadNotificationPermission: loadNotificationPermission,
      requestNotificationPermission: requestNotificationPermission,
      cameraCoordinator: cameraCoordinator,
      onCameraAssistChanged: onCameraAssistChanged,
    ),
  );
}

class _FakeCameraPermissionGateway implements CameraPermissionGateway {
  _FakeCameraPermissionGateway({
    this.requestResult = CameraPermissionState.denied,
  });

  CameraPermissionState current = CameraPermissionState.denied;
  CameraPermissionState requestResult;
  int requestCalls = 0;
  int openSettingsCalls = 0;

  @override
  Future<bool> openSettings() async {
    openSettingsCalls++;
    return true;
  }

  @override
  Future<CameraPermissionState> request() async {
    requestCalls++;
    current = requestResult;
    return current;
  }

  @override
  Future<CameraPermissionState> status() async => current;
}

Future<void> _bringIntoView(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  final center = tester.getCenter(finder);
  if (center.dy > 470) {
    await tester.drag(
      find.byKey(const Key('settingsScrollView')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _openPrivacyTourAndReturnToCamera(
  WidgetTester tester, {
  bool tapTarget = false,
}) async {
  const privacyCopy =
      'Camera assistance is optional. Before enabling it, read Privacy & PDPA '
      'to see how the camera and your data are handled.';
  const cameraCopy =
      'You can turn on camera assistance for extra posture detection, or skip '
      'this step and continue using phone sensors only.';

  expect(find.text(privacyCopy), findsOneWidget);
  final privacyTile = find.byKey(const Key('cameraPrivacySettingsTile'));
  final privacyTarget = tester.getRect(
    find.byKey(CoachMarkOverlay.spotlightKey),
  );
  final privacyRect = tester.getRect(privacyTile);
  expect(privacyTarget.contains(privacyRect.topLeft), isTrue);
  expect(privacyTarget.contains(privacyRect.bottomRight), isTrue);
  expect((privacyTarget.center - privacyRect.center).distance, lessThan(1));

  if (tapTarget) {
    await tester.tap(privacyTile);
  } else {
    await tester.tap(find.byKey(const Key('settingsTourNextButton')));
  }
  await tester.pumpAndSettle();

  expect(find.text('Privacy & PDPA'), findsOneWidget);
  expect(find.text('Camera use'), findsOneWidget);
  expect(find.byType(CoachMarkOverlay), findsNothing);

  await tester.pageBack();
  await tester.pumpAndSettle();

  expect(find.text(cameraCopy), findsOneWidget);
  final cameraSwitch = find.byKey(const Key('cameraAssistEnabledSwitch'));
  final cameraTarget = tester.getRect(
    find.byKey(CoachMarkOverlay.spotlightKey),
  );
  final cameraRect = tester.getRect(cameraSwitch);
  expect(cameraTarget.contains(cameraRect.topLeft), isTrue);
  expect(cameraTarget.contains(cameraRect.bottomRight), isTrue);
  expect((cameraTarget.center - cameraRect.center).distance, lessThan(1));
}

Future<void> _skipCameraTourStep(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('settingsTourSkipButton')));
  await tester.pumpAndSettle();
  expect(find.text('Turn posture tracking on or off.'), findsOneWidget);
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('hides calibration angles and updates status immediately', (
    tester,
  ) async {
    final store = _FakeSettingsStore(AppSettings.defaults);
    var calibration = const Calibration(neutralPhoneAngle: 90);
    await tester.pumpWidget(
      _settingsApp(
        store,
        initialCalibration: calibration,
        currentCalibration: () => calibration,
        onCalibrateNeutral: () async {
          calibration = const Calibration(neutralPhoneAngle: 60);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _bringIntoView(
      tester,
      find.byKey(const Key('calibrationDiagnostics')),
    );

    expect(find.text('Position saved'), findsOneWidget);
    expect(find.textContaining('Neutral angle'), findsNothing);
    expect(find.textContaining('\u00b0'), findsNothing);

    await tester.tap(find.byKey(const Key('calibrateButton')));
    await tester.pumpAndSettle();

    expect(find.text('Position saved'), findsWidgets);
    expect(find.textContaining('threshold'), findsNothing);
  });

  testWidgets(
    'camera explanation precedes permission and denial keeps sensor monitoring',
    (tester) async {
      final gateway = _FakeCameraPermissionGateway();
      final coordinator = CameraAssistPermissionCoordinator(
        preferences: CameraPrivacyPreferences(
          preferences: SharedPreferencesAsync(),
        ),
        permissionGateway: gateway,
        sharedPreferences: SharedPreferencesAsync(),
      );
      final changes = <bool>[];
      await tester.pumpWidget(
        _settingsApp(
          _FakeSettingsStore(AppSettings.defaults),
          loadMonitoringState: () async => true,
          cameraCoordinator: coordinator,
          onCameraAssistChanged: (enabled) async => changes.add(enabled),
        ),
      );
      await tester.pumpAndSettle();

      await _bringIntoView(
        tester,
        find.byKey(const Key('cameraAssistEnabledSwitch')),
      );
      await tester.tap(find.byKey(const Key('cameraAssistEnabledSwitch')));
      await tester.pumpAndSettle();
      expect(find.text('Camera assistance'), findsOneWidget);
      expect(
        find.text(
          'Posture Guard can use your front camera to help improve posture '
          'detection while the app is open.\n\nCamera images are processed '
          'on your device, are not saved, and are not uploaded.\n\nCamera '
          'access is optional. If you choose not to allow it, posture '
          "monitoring will continue using your phone's motion sensors.",
        ),
        findsOneWidget,
      );
      expect(gateway.requestCalls, 0);

      await tester.tap(find.byKey(const Key('cameraExplanationNotNowButton')));
      await tester.pumpAndSettle();
      expect(gateway.requestCalls, 0);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('cameraAssistEnabledSwitch')),
            )
            .value,
        isFalse,
      );

      await tester.tap(find.byKey(const Key('cameraAssistEnabledSwitch')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('cameraExplanationContinueButton')),
      );
      await tester.pumpAndSettle();

      expect(gateway.requestCalls, 1);
      expect(changes, [false]);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('monitoringEnabledSwitch')),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('cameraAssistEnabledSwitch')),
            )
            .value,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('camera grant enables the local feature preference', (
    tester,
  ) async {
    final gateway = _FakeCameraPermissionGateway(
      requestResult: CameraPermissionState.granted,
    );
    final preferences = CameraPrivacyPreferences(
      preferences: SharedPreferencesAsync(),
    );
    final coordinator = CameraAssistPermissionCoordinator(
      preferences: preferences,
      permissionGateway: gateway,
      sharedPreferences: SharedPreferencesAsync(),
    );
    await tester.pumpWidget(
      _settingsApp(
        _FakeSettingsStore(AppSettings.defaults),
        cameraCoordinator: coordinator,
      ),
    );
    await tester.pumpAndSettle();

    await _bringIntoView(
      tester,
      find.byKey(const Key('cameraAssistEnabledSwitch')),
    );
    await tester.tap(find.byKey(const Key('cameraAssistEnabledSwitch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cameraExplanationContinueButton')));
    await tester.pumpAndSettle();

    expect(gateway.requestCalls, 1);
    expect(await preferences.isCameraAssistEnabled(), isTrue);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('cameraAssistEnabledSwitch')),
          )
          .value,
      isTrue,
    );
  });

  testWidgets(
    'Settings tour opens real privacy page then camera Skip changes nothing',
    (tester) async {
      final sharedPreferences = SharedPreferencesAsync();
      final gateway = _FakeCameraPermissionGateway();
      final coordinator = CameraAssistPermissionCoordinator(
        preferences: CameraPrivacyPreferences(preferences: sharedPreferences),
        permissionGateway: gateway,
        sharedPreferences: sharedPreferences,
      );

      await tester.pumpWidget(
        _settingsApp(
          _FakeSettingsStore(AppSettings.defaults),
          showGuidedTour: true,
          screenTimeProvider: _FakeScreenTimeProvider()..supported = false,
          loadNotificationPermission: () async =>
              NotificationPermission.granted,
          cameraCoordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await _openPrivacyTourAndReturnToCamera(tester, tapTarget: true);
      expect(gateway.requestCalls, 0);

      await _skipCameraTourStep(tester);

      expect(gateway.requestCalls, 0);
      expect(
        await sharedPreferences.getBool(
          PreferenceKeys.cameraPrivacyNoticeAcknowledged,
        ),
        isNull,
      );
      expect(
        await sharedPreferences.getBool(PreferenceKeys.cameraAssistEnabled),
        isNull,
      );
    },
  );

  testWidgets(
    'Settings tour enables camera through the existing consent flow',
    (tester) async {
      final sharedPreferences = SharedPreferencesAsync();
      final gateway = _FakeCameraPermissionGateway(
        requestResult: CameraPermissionState.granted,
      );
      final coordinator = CameraAssistPermissionCoordinator(
        preferences: CameraPrivacyPreferences(preferences: sharedPreferences),
        permissionGateway: gateway,
        sharedPreferences: sharedPreferences,
      );

      await tester.pumpWidget(
        _settingsApp(
          _FakeSettingsStore(AppSettings.defaults),
          showGuidedTour: true,
          screenTimeProvider: _FakeScreenTimeProvider()..supported = false,
          loadNotificationPermission: () async =>
              NotificationPermission.granted,
          cameraCoordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();
      await _openPrivacyTourAndReturnToCamera(tester);

      expect(gateway.requestCalls, 0);
      await tester.tap(find.byKey(const Key('cameraAssistEnabledSwitch')));
      await tester.pumpAndSettle();
      expect(find.text('Camera assistance'), findsOneWidget);
      expect(gateway.requestCalls, 0);

      await tester.tap(
        find.byKey(const Key('cameraExplanationContinueButton')),
      );
      await tester.pumpAndSettle();

      expect(gateway.requestCalls, 1);
      expect(
        await sharedPreferences.getBool(PreferenceKeys.cameraAssistEnabled),
        isTrue,
      );
      expect(find.text('Turn posture tracking on or off.'), findsOneWidget);
    },
  );

  testWidgets('Not now on the camera tutorial continues with sensors', (
    tester,
  ) async {
    final sharedPreferences = SharedPreferencesAsync();
    final gateway = _FakeCameraPermissionGateway();
    final coordinator = CameraAssistPermissionCoordinator(
      preferences: CameraPrivacyPreferences(preferences: sharedPreferences),
      permissionGateway: gateway,
      sharedPreferences: sharedPreferences,
    );

    await tester.pumpWidget(
      _settingsApp(
        _FakeSettingsStore(AppSettings.defaults),
        showGuidedTour: true,
        screenTimeProvider: _FakeScreenTimeProvider()..supported = false,
        loadMonitoringState: () async => true,
        loadNotificationPermission: () async => NotificationPermission.granted,
        cameraCoordinator: coordinator,
      ),
    );
    await tester.pumpAndSettle();
    await _openPrivacyTourAndReturnToCamera(tester);

    await tester.tap(find.byKey(const Key('settingsTourNextButton')));
    await tester.pumpAndSettle();
    expect(find.text('Camera assistance'), findsOneWidget);
    expect(gateway.requestCalls, 0);

    await tester.tap(find.byKey(const Key('cameraExplanationNotNowButton')));
    await tester.pumpAndSettle();

    expect(gateway.requestCalls, 0);
    expect(find.text('Turn posture tracking on or off.'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('monitoringEnabledSwitch')),
          )
          .value,
      isTrue,
    );
  });

  testWidgets(
    'replay recognizes configured camera and screen time without resetting them',
    (tester) async {
      final sharedPreferences = SharedPreferencesAsync();
      await sharedPreferences.setBool(
        PreferenceKeys.cameraPrivacyNoticeAcknowledged,
        true,
      );
      await sharedPreferences.setBool(PreferenceKeys.cameraAssistEnabled, true);
      final gateway = _FakeCameraPermissionGateway()
        ..current = CameraPermissionState.granted;
      final coordinator = CameraAssistPermissionCoordinator(
        preferences: CameraPrivacyPreferences(preferences: sharedPreferences),
        permissionGateway: gateway,
        sharedPreferences: sharedPreferences,
      );
      final screenTime = _FakeScreenTimeProvider()..hasAccess = true;

      await tester.pumpWidget(
        _settingsApp(
          _FakeSettingsStore(AppSettings.defaults),
          showGuidedTour: true,
          screenTimeProvider: screenTime,
          loadNotificationPermission: () async =>
              NotificationPermission.granted,
          cameraCoordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();
      await _openPrivacyTourAndReturnToCamera(tester);

      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.byKey(const Key('settingsTourNextButton')));
      await tester.pumpAndSettle();
      expect(gateway.requestCalls, 0);

      await tester.tap(find.byKey(const Key('settingsTourNextButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settingsTourNextButton')));
      await tester.pumpAndSettle();

      expect(find.text('Show your screen time'), findsNothing);
      expect(
        find.text('Choose how long Posture Guard waits before reminding you.'),
        findsOneWidget,
      );
      expect(
        await sharedPreferences.getBool(
          PreferenceKeys.cameraPrivacyNoticeAcknowledged,
        ),
        isTrue,
      );
      expect(
        await sharedPreferences.getBool(PreferenceKeys.cameraAssistEnabled),
        isTrue,
      );
    },
  );

  testWidgets('Settings tour completes without camera or screen-time access', (
    tester,
  ) async {
    final sharedPreferences = SharedPreferencesAsync();
    final gateway = _FakeCameraPermissionGateway();
    final coordinator = CameraAssistPermissionCoordinator(
      preferences: CameraPrivacyPreferences(preferences: sharedPreferences),
      permissionGateway: gateway,
      sharedPreferences: sharedPreferences,
    );
    final screenTime = _FakeScreenTimeProvider();

    await tester.pumpWidget(
      _settingsApp(
        _FakeSettingsStore(AppSettings.defaults),
        showGuidedTour: true,
        screenTimeProvider: screenTime,
        loadNotificationPermission: () async => NotificationPermission.granted,
        cameraCoordinator: coordinator,
      ),
    );
    await tester.pumpAndSettle();
    await _openPrivacyTourAndReturnToCamera(tester);
    await _skipCameraTourStep(tester);

    await tester.tap(find.byKey(const Key('settingsTourNextButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsTourNextButton')));
    await tester.pumpAndSettle();
    expect(find.text('Show your screen time'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settingsTourSkipButton')));
    await tester.pumpAndSettle();

    for (var remainingStep = 0; remainingStep < 4; remainingStep++) {
      await tester.tap(find.byKey(const Key('settingsTourNextButton')));
      await tester.pumpAndSettle();
    }

    expect(find.byType(CoachMarkOverlay), findsNothing);
    expect(gateway.requestCalls, 0);
    expect(screenTime.settingsOpens, 0);
    expect(
      await sharedPreferences.getBool(PreferenceKeys.cameraAssistEnabled),
      isNull,
    );
  });

  testWidgets('Settings opens the complete English Privacy & PDPA page', (
    tester,
  ) async {
    await tester.pumpWidget(
      _settingsApp(_FakeSettingsStore(AppSettings.defaults)),
    );
    await tester.pumpAndSettle();

    final privacyTile = find.byKey(const Key('cameraPrivacySettingsTile'));
    await _bringIntoView(tester, privacyTile);
    expect(find.text('Privacy & PDPA'), findsOneWidget);

    await tester.tap(privacyTile);
    await tester.pumpAndSettle();

    expect(find.text('Privacy & PDPA'), findsOneWidget);
    expect(find.text('Posture and motion data'), findsOneWidget);
    expect(find.text('Camera use'), findsOneWidget);
    expect(find.text('Data kept on this device'), findsOneWidget);
    expect(find.text('Firebase and cloud data'), findsOneWidget);
    expect(find.text('Device screen time'), findsOneWidget);
    expect(find.text('Alerts, permissions, and your choices'), findsOneWidget);
    expect(find.text('Delete your data'), findsOneWidget);
    expect(find.text('About PDPA'), findsOneWidget);
    expect(
      find.byKey(const Key('turnOffCameraAssistanceButton')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('deleteMyDataButton')), findsOneWidget);
    expect(find.textContaining('PDPA compliant'), findsNothing);
    expect(find.textContaining('legally compliant'), findsNothing);
  });

  testWidgets('iOS privacy copy omits Android Usage Access behavior', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      _settingsApp(_FakeSettingsStore(AppSettings.defaults)),
    );
    await tester.pumpAndSettle();

    final privacyTile = find.byKey(const Key('cameraPrivacySettingsTile'));
    await _bringIntoView(tester, privacyTile);
    await tester.tap(privacyTile);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Whole-device screen time is not available'),
      findsOneWidget,
    );
    expect(find.textContaining('filters Android usage events'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Thai Settings exposes ความเป็นส่วนตัวและ PDPA', (tester) async {
    await tester.pumpWidget(
      _settingsApp(
        _FakeSettingsStore(AppSettings.defaults),
        locale: const Locale('th'),
      ),
    );
    await tester.pumpAndSettle();

    final privacyTile = find.byKey(const Key('cameraPrivacySettingsTile'));
    await _bringIntoView(tester, privacyTile);
    expect(find.text('ความเป็นส่วนตัวและ PDPA'), findsOneWidget);

    await tester.tap(privacyTile);
    await tester.pumpAndSettle();

    expect(find.text('ความเป็นส่วนตัวและ PDPA'), findsOneWidget);
    expect(find.text('ข้อมูลท่าทางและการเคลื่อนไหว'), findsOneWidget);
    expect(find.text('การใช้กล้อง'), findsOneWidget);
    expect(find.text('ข้อมูลที่เก็บในอุปกรณ์นี้'), findsOneWidget);
    expect(find.text('เวลาหน้าจอของอุปกรณ์'), findsOneWidget);
    expect(find.text('การลบข้อมูล'), findsOneWidget);
    expect(find.text('เกี่ยวกับ PDPA'), findsOneWidget);
    expect(find.byKey(const Key('deleteMyDataButton')), findsOneWidget);
  });

  testWidgets(
    'failed recalibration preserves previous diagnostics and settings',
    (tester) async {
      final originalSettings = AppSettings.defaults.copyWith(
        monitoringEnabled: false,
        alertsEnabled: false,
      );
      final store = _FakeSettingsStore(originalSettings);
      const calibration = Calibration(neutralPhoneAngle: 72);
      await tester.pumpWidget(
        _settingsApp(
          store,
          initialCalibration: calibration,
          currentCalibration: () => calibration,
          onCalibrateNeutral: () async => false,
        ),
      );
      await tester.pumpAndSettle();
      await _bringIntoView(tester, find.byKey(const Key('calibrateButton')));

      await tester.tap(find.byKey(const Key('calibrateButton')));
      await tester.pumpAndSettle();

      expect(find.text('Position saved'), findsOneWidget);
      expect(find.textContaining('\u00b0'), findsNothing);
      expect(store.settings, originalSettings);
      expect(store.savedSettings, isNull);
    },
  );

  testWidgets('active temporary mute is compact and can be cleared', (
    tester,
  ) async {
    final store = _FakeSettingsStore(AppSettings.defaults);
    final muteStore = _FakeMuteStore()
      ..value = DateTime(2026, 7, 26, 15).millisecondsSinceEpoch;
    var now = DateTime(2026, 7, 26, 14, 30);
    final controller = AlertMuteController(store: muteStore, clock: () => now);

    await tester.pumpWidget(
      _settingsApp(
        store,
        alertMuteController: controller,
        onAlertMuteChanged: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('temporaryAlertMuteStatus')), findsOneWidget);
    expect(find.text('Unmute now'), findsOneWidget);

    await tester.tap(find.byKey(const Key('unmuteAlertsButton')));
    await tester.pump();

    expect(muteStore.value, isNull);
    expect(find.byKey(const Key('temporaryAlertMuteStatus')), findsNothing);
    expect(store.settings.alertsEnabled, isTrue);
    now = now.add(const Duration(minutes: 1));
  });

  testWidgets('loads existing values and keeps Save reachable', (tester) async {
    final store = _FakeSettingsStore(
      const AppSettings(
        monitoringEnabled: true,
        alertDelaySeconds: 30,
        alertFrequencySeconds: 300,
        alertsEnabled: true,
      ),
    );

    await tester.pumpWidget(_settingsApp(store));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Custom'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('customDelayField')))
          .controller
          ?.text,
      '30',
    );
    expect(find.text('5 minutes'), findsOneWidget);
    expect(find.byKey(const Key('saveSettingsButton')), findsOneWidget);
  });

  testWidgets('alert delay offers 5, 10, 15 seconds and sends changes', (
    tester,
  ) async {
    final store = _FakeSettingsStore(AppSettings.defaults);
    AppSettings? communicatedSettings;
    await tester.pumpWidget(
      _settingsApp(
        store,
        onSettingsSaved: (settings) async {
          communicatedSettings = settings;
        },
      ),
    );
    await tester.pumpAndSettle();
    await _bringIntoView(tester, find.byKey(const Key('alertDelayDropdown')));
    await tester.tap(find.byKey(const Key('alertDelayDropdown')));
    await tester.pumpAndSettle();

    expect(find.text('5 seconds'), findsOneWidget);
    expect(find.text('10 seconds'), findsWidgets);
    expect(find.text('15 seconds'), findsWidgets);
    // The one remaining 30-second label belongs to repeat frequency, not delay.
    expect(find.text('30 seconds'), findsOneWidget);

    await tester.tap(find.text('15 seconds').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveSettingsButton')));
    await tester.pumpAndSettle();

    expect(store.savedSettings?.alertDelaySeconds, 15);
    expect(communicatedSettings?.alertDelaySeconds, 15);
  });

  testWidgets('changing frequency updates and saves selected value', (
    tester,
  ) async {
    final store = _FakeSettingsStore(
      const AppSettings(
        monitoringEnabled: true,
        alertDelaySeconds: 10,
        alertFrequencySeconds: 15,
        alertsEnabled: true,
      ),
    );
    await tester.pumpWidget(_settingsApp(store));
    await tester.pumpAndSettle();

    await _bringIntoView(
      tester,
      find.byKey(const Key('alertFrequencyDropdown')),
    );
    await tester.tap(find.byKey(const Key('alertFrequencyDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 seconds').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveSettingsButton')));
    await tester.pumpAndSettle();

    expect(store.savedSettings?.alertFrequencySeconds, 30);
    expect(find.text('Settings saved.'), findsOneWidget);
  });

  testWidgets('rejects an invalid custom frequency', (tester) async {
    final store = _FakeSettingsStore(AppSettings.defaults);
    await tester.pumpWidget(_settingsApp(store));
    await tester.pumpAndSettle();

    await _bringIntoView(
      tester,
      find.byKey(const Key('alertFrequencyDropdown')),
    );
    await tester.tap(find.byKey(const Key('alertFrequencyDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();
    await _bringIntoView(tester, find.byKey(const Key('customFrequencyField')));
    await tester.enterText(find.byKey(const Key('customFrequencyField')), '0');
    await tester.tap(find.byKey(const Key('saveSettingsButton')));
    await tester.pump();

    expect(find.text('Use 5–3600 seconds.'), findsOneWidget);
    expect(store.savedSettings, isNull);
  });

  testWidgets('reports Firebase save failure without losing local save', (
    tester,
  ) async {
    final store = _FakeSettingsStore(
      AppSettings.defaults,
      saveResult: const SettingsSaveResult(
        savedLocally: true,
        savedToFirebase: false,
      ),
    );
    await tester.pumpWidget(_settingsApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveSettingsButton')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Settings were saved on this device. Cloud backup will try again later.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('master switch starts once and is disabled while in flight', (
    tester,
  ) async {
    final store = _FakeSettingsStore(
      AppSettings.defaults.copyWith(monitoringEnabled: false),
    );
    final startResult = Completer<MonitoringControlResult>();
    var startCalls = 0;

    await tester.pumpWidget(
      _settingsApp(
        store,
        loadMonitoringState: () async => false,
        onMonitoringEnabledChanged: (enabled) {
          startCalls++;
          expect(enabled, isTrue);
          return startResult.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start Monitoring'), findsNothing);
    expect(find.text('Stop Monitoring'), findsNothing);
    expect(find.text('Posture Guard is off.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('monitoringEnabledSwitch')));
    await tester.pump();
    var tile = tester.widget<SwitchListTile>(
      find.byKey(const Key('monitoringEnabledSwitch')),
    );
    expect(tile.value, isTrue);
    expect(tile.onChanged, isNull);
    await tester.tap(find.byKey(const Key('monitoringEnabledSwitch')));
    expect(startCalls, 1);

    startResult.complete(
      const MonitoringControlResult(
        success: true,
        isActive: true,
        message: 'Monitoring started.',
      ),
    );
    await tester.pumpAndSettle();

    tile = tester.widget<SwitchListTile>(
      find.byKey(const Key('monitoringEnabledSwitch')),
    );
    expect(tile.value, isTrue);
    expect(find.text('Posture Guard is working.'), findsOneWidget);
    expect(store.savedSettings?.monitoringEnabled, isTrue);
  });

  testWidgets('master switch stops monitoring once', (tester) async {
    final store = _FakeSettingsStore(AppSettings.defaults);
    var stopCalls = 0;

    await tester.pumpWidget(
      _settingsApp(
        store,
        loadMonitoringState: () async => true,
        onMonitoringEnabledChanged: (enabled) async {
          stopCalls++;
          expect(enabled, isFalse);
          return const MonitoringControlResult(success: true, isActive: false);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('monitoringEnabledSwitch')));
    await tester.pumpAndSettle();

    expect(stopCalls, 1);
    expect(store.savedSettings?.monitoringEnabled, isFalse);
    expect(find.text('Posture Guard is off.'), findsOneWidget);
  });

  testWidgets('failed stop restores the accurate enabled state', (
    tester,
  ) async {
    final store = _FakeSettingsStore(AppSettings.defaults);

    await tester.pumpWidget(
      _settingsApp(
        store,
        loadMonitoringState: () async => true,
        onMonitoringEnabledChanged: (enabled) async {
          return const MonitoringControlResult(
            success: false,
            isActive: true,
            message: 'Android could not stop monitoring.',
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('monitoringEnabledSwitch')));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(
      find.byKey(const Key('monitoringEnabledSwitch')),
    );
    expect(tile.value, isTrue);
    expect(store.savedSettings?.monitoringEnabled, isTrue);
    expect(find.textContaining('could not stop'), findsOneWidget);
  });

  testWidgets('failed start returns the master switch to off', (tester) async {
    final store = _FakeSettingsStore(
      AppSettings.defaults.copyWith(monitoringEnabled: false),
    );

    await tester.pumpWidget(
      _settingsApp(
        store,
        loadMonitoringState: () async => false,
        onMonitoringEnabledChanged: (enabled) async {
          return const MonitoringControlResult(
            success: false,
            isActive: false,
            message: 'Open Android settings and try again.',
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('monitoringEnabledSwitch')));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(
      find.byKey(const Key('monitoringEnabledSwitch')),
    );
    expect(tile.value, isFalse);
    expect(store.savedSettings?.monitoringEnabled, isFalse);
    expect(find.textContaining('Open Android settings'), findsOneWidget);
  });

  testWidgets('cloud failure preserves the locally enabled master switch', (
    tester,
  ) async {
    final store = _FakeSettingsStore(
      AppSettings.defaults.copyWith(monitoringEnabled: false),
      saveResult: const SettingsSaveResult(
        savedLocally: true,
        savedToFirebase: false,
      ),
    );

    await tester.pumpWidget(
      _settingsApp(
        store,
        loadMonitoringState: () async => false,
        onMonitoringEnabledChanged: (enabled) async =>
            MonitoringControlResult(success: true, isActive: enabled),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('monitoringEnabledSwitch')));
    await tester.pumpAndSettle();

    final tile = tester.widget<SwitchListTile>(
      find.byKey(const Key('monitoringEnabledSwitch')),
    );
    expect(tile.value, isTrue);
    expect(store.savedSettings?.monitoringEnabled, isTrue);
    expect(find.textContaining('Cloud backup will try again'), findsOneWidget);
  });

  testWidgets('alert switch saves and updates service without stopping it', (
    tester,
  ) async {
    final store = _FakeSettingsStore(AppSettings.defaults);
    AppSettings? communicatedSettings;
    var monitoringActions = 0;

    await tester.pumpWidget(
      _settingsApp(
        store,
        loadMonitoringState: () async => true,
        onMonitoringEnabledChanged: (enabled) async {
          monitoringActions++;
          return MonitoringControlResult(success: true, isActive: enabled);
        },
        onSettingsSaved: (settings) async {
          communicatedSettings = settings;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('alertsEnabledSwitch')));
    await tester.pumpAndSettle();

    expect(store.savedSettings?.alertsEnabled, isFalse);
    expect(communicatedSettings?.alertsEnabled, isFalse);
    expect(communicatedSettings?.monitoringEnabled, isTrue);
    expect(monitoringActions, 0);
  });

  testWidgets('uses clamped scrolling and keeps lower controls reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _FakeSettingsStore(AppSettings.defaults);
    await tester.pumpWidget(
      _settingsApp(
        store,
        loadMonitoringState: () async => true,
        onMonitoringEnabledChanged: (enabled) async =>
            MonitoringControlResult(success: true, isActive: enabled),
        initialHasCalibration: true,
      ),
    );
    await tester.pumpAndSettle();

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('settingsScrollView')),
    );
    expect(scrollView.physics, isA<ClampingScrollPhysics>());
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byKey(const Key('saveSettingsButton')), findsOneWidget);

    await _bringIntoView(tester, find.byKey(const Key('calibrateButton')));
    expect(find.byKey(const Key('calibrateButton')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Usage Access is optional, user initiated, and rechecked', (
    tester,
  ) async {
    final store = _FakeSettingsStore(AppSettings.defaults);
    final provider = _FakeScreenTimeProvider();
    await tester.pumpWidget(
      _settingsApp(
        store,
        screenTimeProvider: provider,
        loadMonitoringState: () async => true,
      ),
    );
    await tester.pumpAndSettle();

    await _bringIntoView(
      tester,
      find.byKey(const Key('allowScreenTimeAccessButton')),
    );
    expect(find.text('Use device screen time'), findsOneWidget);
    expect(find.text('Access not granted'), findsOneWidget);
    expect(
      find.byKey(const Key('allowScreenTimeAccessButton')),
      findsOneWidget,
    );
    expect(provider.settingsOpens, 0);

    await tester.tap(find.byKey(const Key('allowScreenTimeAccessButton')));
    await tester.pump();
    expect(provider.settingsOpens, 1);

    provider.hasAccess = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Access granted'), findsOneWidget);
    expect(find.byKey(const Key('allowScreenTimeAccessButton')), findsNothing);
  });

  testWidgets('recalibration preserves unrelated disabled settings', (
    tester,
  ) async {
    final original = AppSettings.defaults.copyWith(
      monitoringEnabled: false,
      alertsEnabled: false,
    );
    final store = _FakeSettingsStore(original);
    var calibrations = 0;

    await tester.pumpWidget(
      _settingsApp(
        store,
        loadMonitoringState: () async => false,
        onMonitoringEnabledChanged: (enabled) async =>
            MonitoringControlResult(success: true, isActive: enabled),
        onCalibrateNeutral: () async {
          calibrations++;
          return true;
        },
        initialHasCalibration: true,
      ),
    );
    await tester.pumpAndSettle();
    await _bringIntoView(tester, find.byKey(const Key('calibrateButton')));

    await tester.tap(find.byKey(const Key('calibrateButton')));
    await tester.pumpAndSettle();

    expect(calibrations, 1);
    expect(store.settings, original);
    expect(store.savedSettings, isNull);
  });

  testWidgets('guided tour explains real controls without changing values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = AppSettings.defaults.copyWith(alertsEnabled: false);
    final store = _FakeSettingsStore(original);
    final provider = _FakeScreenTimeProvider()..supported = false;

    await tester.pumpWidget(
      _settingsApp(store, showGuidedTour: true, screenTimeProvider: provider),
    );
    await tester.pumpAndSettle();

    await _openPrivacyTourAndReturnToCamera(tester, tapTarget: true);
    await _skipCameraTourStep(tester);

    expect(find.text('Turn posture tracking on or off.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settingsTourNextButton')));
    await tester.pumpAndSettle();
    expect(
      find.text('Choose whether you want posture reminders.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('settingsTourNextButton')));
    await tester.pumpAndSettle();
    expect(
      find.text('Choose how long Posture Guard waits before reminding you.'),
      findsOneWidget,
    );
    expect(store.settings, original);
    expect(store.savedSettings, isNull);

    await tester.tap(find.byKey(const Key('settingsTourBackButton')));
    await tester.pumpAndSettle();
    expect(
      find.text('Choose whether you want posture reminders.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing screen-time access is optional and user initiated', (
    tester,
  ) async {
    final store = _FakeSettingsStore(AppSettings.defaults);
    final provider = _FakeScreenTimeProvider();
    await tester.pumpWidget(
      _settingsApp(store, showGuidedTour: true, screenTimeProvider: provider),
    );
    await tester.pumpAndSettle();

    await _openPrivacyTourAndReturnToCamera(tester);
    await _skipCameraTourStep(tester);
    await tester.tap(find.byKey(const Key('settingsTourNextButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsTourNextButton')));
    await tester.pumpAndSettle();

    expect(find.text('Show your screen time'), findsOneWidget);
    expect(
      find.text(
        "Screen-time access is optional. Allow it to show today's total "
        "phone screen time, or skip and use Posture Guard's monitored-time "
        'fallback.',
      ),
      findsOneWidget,
    );
    expect(provider.settingsOpens, 0);

    await tester.tap(find.byKey(const Key('settingsTourNextButton')));
    await tester.pump();
    expect(provider.settingsOpens, 1);
    expect(find.byKey(const Key('settingsTourNextButton')), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(provider.settingsOpens, 1);
    await tester.tap(find.byKey(const Key('settingsTourSkipButton')));
    await tester.pumpAndSettle();
    expect(find.text('Show your screen time'), findsNothing);
    expect(find.text('Alert delay'), findsWidgets);
  });

  testWidgets(
    'notification permission is requested only from the Allow action',
    (tester) async {
      var requests = 0;
      final screenTime = _FakeScreenTimeProvider()..supported = false;
      await tester.pumpWidget(
        _settingsApp(
          _FakeSettingsStore(AppSettings.defaults),
          showGuidedTour: true,
          screenTimeProvider: screenTime,
          loadNotificationPermission: () async => NotificationPermission.denied,
          requestNotificationPermission: () async {
            requests++;
            return NotificationPermission.denied;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(requests, 0);
      await _openPrivacyTourAndReturnToCamera(tester);
      await _skipCameraTourStep(tester);
      await tester.tap(find.byKey(const Key('settingsTourNextButton')));
      await tester.pumpAndSettle();
      expect(find.text('Allow notifications'), findsWidgets);
      expect(requests, 0);

      await tester.tap(find.byKey(const Key('settingsTourNextButton')));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(
        find.text('Choose how long Posture Guard waits before reminding you.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('granted screen-time access skips the optional prompt', (
    tester,
  ) async {
    final provider = _FakeScreenTimeProvider()..hasAccess = true;
    await tester.pumpWidget(
      _settingsApp(
        _FakeSettingsStore(AppSettings.defaults),
        showGuidedTour: true,
        screenTimeProvider: provider,
      ),
    );
    await tester.pumpAndSettle();

    await _openPrivacyTourAndReturnToCamera(tester);
    await _skipCameraTourStep(tester);
    await tester.tap(find.byKey(const Key('settingsTourNextButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsTourNextButton')));
    await tester.pumpAndSettle();
    expect(find.text('Show your screen time'), findsNothing);
    expect(
      find.text('Choose how long Posture Guard waits before reminding you.'),
      findsOneWidget,
    );
  });

  testWidgets('iOS guided tour never includes Android Usage Access', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      _settingsApp(
        _FakeSettingsStore(AppSettings.defaults),
        showGuidedTour: true,
        loadNotificationPermission: () async => NotificationPermission.granted,
      ),
    );
    await tester.pumpAndSettle();

    await _openPrivacyTourAndReturnToCamera(tester);
    await _skipCameraTourStep(tester);
    await tester.tap(find.byKey(const Key('settingsTourNextButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsTourNextButton')));
    await tester.pumpAndSettle();

    expect(find.text('Show your screen time'), findsNothing);
    expect(find.byKey(const Key('allowScreenTimeAccessButton')), findsNothing);
    expect(
      find.text('Choose how long Posture Guard waits before reminding you.'),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Thai guided Settings copy fits scaled phone text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final provider = _FakeScreenTimeProvider()..supported = false;

    await tester.pumpWidget(
      _settingsApp(
        _FakeSettingsStore(AppSettings.defaults),
        showGuidedTour: true,
        screenTimeProvider: provider,
        locale: const Locale('th'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'การช่วยตรวจท่าด้วยกล้องเป็นทางเลือก ก่อนเปิดใช้งาน '
        'โปรดอ่านความเป็นส่วนตัวและ PDPA '
        'เพื่อดูวิธีใช้กล้องและจัดการข้อมูลของคุณ',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('cameraPrivacySettingsTile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deleteMyDataButton')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.text(
        'คุณสามารถเปิดกล้องเพื่อช่วยตรวจจับท่าทางเพิ่มเติม '
        'หรือข้ามขั้นตอนนี้และใช้เฉพาะเซ็นเซอร์ของโทรศัพท์ต่อไปได้',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
