import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/models/app_settings.dart';
import 'package:postureguard/models/calibration.dart';
import 'package:postureguard/pages/settings_page.dart';
import 'package:postureguard/services/alert_mute_service.dart';
import 'package:postureguard/services/device_screen_time_service.dart';
import 'package:postureguard/services/preferences_service.dart';
import 'package:postureguard/widgets/no_stretch_scroll_behavior.dart';

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
}) {
  return MaterialApp(
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
    ),
  );
}

void main() {
  testWidgets(
    'shows adaptive calibration diagnostics and updates immediately',
    (tester) async {
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
      await tester.scrollUntilVisible(
        find.byKey(const Key('calibrationDiagnostics')),
        300,
      );

      expect(find.textContaining('Neutral angle: 90\u00b0'), findsOneWidget);
      expect(
        find.textContaining('Bad posture below: 63\u00b0'),
        findsOneWidget,
      );

      await tester.tap(find.text('Recalibrate neutral posture'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Neutral angle: 60\u00b0'), findsOneWidget);
      expect(
        find.textContaining('Bad posture below: 42\u00b0'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Return to good above: 47\u00b0'),
        findsOneWidget,
      );
    },
  );

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
      await tester.scrollUntilVisible(
        find.text('Recalibrate neutral posture'),
        300,
      );

      await tester.tap(find.text('Recalibrate neutral posture'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Neutral angle: 72\u00b0'), findsOneWidget);
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

    expect(find.text('30 seconds'), findsOneWidget);
    expect(find.text('5 minutes'), findsOneWidget);
    expect(find.byKey(const Key('saveSettingsButton')), findsOneWidget);
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

    await tester.tap(find.byKey(const Key('alertFrequencyDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 seconds').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveSettingsButton')));
    await tester.pumpAndSettle();

    expect(store.savedSettings?.alertFrequencySeconds, 30);
    expect(find.text('Settings saved successfully.'), findsOneWidget);
  });

  testWidgets('rejects an invalid custom frequency', (tester) async {
    final store = _FakeSettingsStore(AppSettings.defaults);
    await tester.pumpWidget(_settingsApp(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('alertFrequencyDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('customFrequencyField')),
      300,
    );
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
        'Settings were saved on this device, but Firebase sync failed.',
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
    expect(find.text('Posture monitoring is disabled.'), findsOneWidget);

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
    expect(find.text('Posture monitoring is active.'), findsOneWidget);
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
    expect(find.text('Posture monitoring is disabled.'), findsOneWidget);
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
    expect(find.textContaining('cloud synchronization failed'), findsOneWidget);
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

    final listView = tester.widget<ListView>(
      find.byKey(const Key('settingsScrollView')),
    );
    expect(listView.physics, isA<ClampingScrollPhysics>());
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byKey(const Key('saveSettingsButton')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Recalibrate neutral posture'),
      300,
    );
    expect(find.text('Recalibrate neutral posture'), findsOneWidget);
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

    expect(find.text('Use device screen time'), findsOneWidget);
    expect(find.text('Usage Access not granted.'), findsOneWidget);
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
    expect(find.text('Usage Access granted.'), findsOneWidget);
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
    await tester.scrollUntilVisible(
      find.text('Recalibrate neutral posture'),
      300,
    );

    await tester.tap(find.text('Recalibrate neutral posture'));
    await tester.pumpAndSettle();

    expect(calibrations, 1);
    expect(store.settings, original);
    expect(store.savedSettings, isNull);
  });
}
