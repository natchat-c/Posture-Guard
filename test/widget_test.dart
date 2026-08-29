import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/services/preferences_service.dart';
import 'package:postureguard/services/app_startup_coordinator.dart';
import 'package:postureguard/services/monitoring_service.dart';
import 'package:postureguard/models/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:postureguard/main.dart';

class _SensorOnlySettingsStore implements SettingsStore {
  static const settings = AppSettings(
    monitoringEnabled: false,
    alertDelaySeconds: AppSettings.defaultAlertDelaySeconds,
    alertFrequencySeconds: AppSettings.defaultAlertFrequencySeconds,
    alertsEnabled: true,
  );

  @override
  Future<SettingsLoadResult> load() async {
    return const SettingsLoadResult(settings: settings);
  }

  @override
  Future<SettingsSaveResult> save(AppSettings value) async {
    return const SettingsSaveResult(savedLocally: true, savedToFirebase: true);
  }
}

class _LifecycleRecordingMonitoringService
    extends UnsupportedBackgroundMonitoringPlatformService {
  final List<AppLifecycleState> states = [];

  @override
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    states.add(state);
  }
}

void main() {
  testWidgets('app lifecycle is forwarded to the monitoring platform', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          PreferenceKeys.selectedLanguageCode: 'en',
        });
    final service = _LifecycleRecordingMonitoringService();
    MonitoringService.usePlatformServiceForTesting(service);
    addTearDown(MonitoringService.resetPlatformServiceForTesting);

    await tester.pumpWidget(const MyApp(initialTutorialCompleted: false));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(
      service.states,
      containsAllInOrder(const [
        AppLifecycleState.paused,
        AppLifecycleState.resumed,
      ]),
    );
  });

  testWidgets('first launch shows privacy after language and before tutorial', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await tester.pumpWidget(const MyApp(initialTutorialCompleted: false));
    await tester.pumpAndSettle();

    expect(find.text('Choose your language'), findsOneWidget);
    expect(find.text('เลือกภาษา'), findsOneWidget);
    await tester.tap(find.byKey(const Key('languageContinueButton')));
    await tester.pumpAndSettle();
    expect(find.text('Camera privacy'), findsOneWidget);
    expect(find.text('Welcome to Posture Guard'), findsNothing);
    expect(
      await SharedPreferencesAsync().getBool(
        PreferenceKeys.cameraPermissionRequested,
      ),
      isNull,
    );

    await tester.tap(find.byKey(const Key('privacyNoticeSensorsOnlyButton')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Posture Guard'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    final preferences = SharedPreferencesAsync();
    expect(
      await preferences.getBool(PreferenceKeys.cameraPrivacyNoticeAcknowledged),
      isTrue,
    );
    expect(
      await preferences.getBool(PreferenceKeys.cameraAssistEnabled),
      isFalse,
    );
    expect(
      await preferences.getBool(PreferenceKeys.cameraPermissionRequested),
      isNull,
    );
  });

  test('privacy acknowledgement does not reset an existing tutorial', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          PreferenceKeys.hasCompletedTutorial: true,
        });
    final preferences = SharedPreferencesAsync();

    await preferences.setBool(
      PreferenceKeys.cameraPrivacyNoticeAcknowledged,
      true,
    );
    await preferences.setBool(PreferenceKeys.cameraAssistEnabled, false);

    expect(
      await preferences.getBool(PreferenceKeys.hasCompletedTutorial),
      isTrue,
    );
  });

  testWidgets('acknowledged privacy notice appears only once', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          PreferenceKeys.selectedLanguageCode: 'en',
          PreferenceKeys.cameraPrivacyNoticeAcknowledged: true,
        });

    await tester.pumpWidget(const MyApp(initialTutorialCompleted: false));
    await tester.pumpAndSettle();

    expect(find.text('Camera privacy'), findsNothing);
    expect(find.text('Welcome to Posture Guard'), findsOneWidget);
  });

  testWidgets('existing completed users are not sent through new onboarding', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          PreferenceKeys.selectedLanguageCode: 'en',
          PreferenceKeys.hasCompletedTutorial: true,
        });
    final coordinator = AppStartupCoordinator(
      settingsStore: _SensorOnlySettingsStore(),
      isMonitoringRunning: () async => false,
    );

    await tester.pumpWidget(
      MyApp(
        startupCoordinator: coordinator,
        homeBuilder: (_) => const Scaffold(body: Text('Existing home')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Existing home'), findsOneWidget);
    expect(find.text('Camera privacy'), findsNothing);
    expect(
      await SharedPreferencesAsync().getBool(
        PreferenceKeys.hasCompletedTutorial,
      ),
      isTrue,
    );
  });
}
