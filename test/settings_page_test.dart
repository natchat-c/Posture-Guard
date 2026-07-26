import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/models/app_settings.dart';
import 'package:postureguard/pages/settings_page.dart';
import 'package:postureguard/services/preferences_service.dart';

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

Widget _settingsApp(
  _FakeSettingsStore store, {
  Future<bool> Function()? loadMonitoringState,
  Future<MonitoringControlResult> Function()? onStartMonitoring,
  Future<MonitoringControlResult> Function()? onStopMonitoring,
  bool initialHasCalibration = false,
}) {
  return MaterialApp(
    home: Settings(
      store: store,
      onCalibrateNeutral: () async => true,
      loadMonitoringState: loadMonitoringState,
      onStartMonitoring: onStartMonitoring,
      onStopMonitoring: onStopMonitoring,
      initialHasCalibration: initialHasCalibration,
    ),
  );
}

void main() {
  testWidgets('loads existing values and keeps Save reachable', (tester) async {
    final store = _FakeSettingsStore(
      const AppSettings(
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

  testWidgets(
    'shows only the appropriate monitoring action and blocks duplicate starts',
    (tester) async {
      final store = _FakeSettingsStore(AppSettings.defaults);
      final startResult = Completer<MonitoringControlResult>();
      var startCalls = 0;

      await tester.pumpWidget(
        _settingsApp(
          store,
          loadMonitoringState: () async => false,
          onStartMonitoring: () {
            startCalls++;
            return startResult.future;
          },
          onStopMonitoring: () async => const MonitoringControlResult(
            success: true,
            isActive: false,
            message: 'Monitoring stopped.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Monitoring stopped'), findsOneWidget);
      expect(find.text('Start Monitoring'), findsOneWidget);
      expect(find.text('Stop Monitoring'), findsNothing);

      await tester.tap(find.byKey(const Key('settingsMonitoringButton')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('settingsMonitoringButton')));
      expect(startCalls, 1);

      startResult.complete(
        const MonitoringControlResult(
          success: true,
          isActive: true,
          message: 'Monitoring started.',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Monitoring active'), findsOneWidget);
      expect(find.text('Stop Monitoring'), findsOneWidget);
      expect(find.text('Start Monitoring'), findsNothing);
    },
  );

  testWidgets('reloads active service state and exposes recalibration', (
    tester,
  ) async {
    final store = _FakeSettingsStore(AppSettings.defaults);

    await tester.pumpWidget(
      _settingsApp(
        store,
        loadMonitoringState: () async => true,
        onStopMonitoring: () async =>
            const MonitoringControlResult(success: true, isActive: false),
        initialHasCalibration: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monitoring active'), findsOneWidget);
    expect(find.text('Stop Monitoring'), findsOneWidget);
    expect(find.text('Start Monitoring'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Recalibrate neutral posture'),
      300,
    );
    expect(find.text('Recalibrate neutral posture'), findsOneWidget);
  });
}
