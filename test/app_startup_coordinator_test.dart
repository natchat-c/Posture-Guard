import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postureguard/models/app_settings.dart';
import 'package:postureguard/services/app_startup_coordinator.dart';
import 'package:postureguard/services/monitoring_service.dart';
import 'package:postureguard/services/preferences_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _FakeTutorialPreferences extends TutorialPreferences {
  _FakeTutorialPreferences({this.completed = false});

  bool completed;
  int completionWrites = 0;

  @override
  Future<bool> hasCompletedTutorial() async => completed;

  @override
  Future<void> markCompleted() async {
    completed = true;
    completionWrites++;
  }
}

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
  int saveCalls = 0;

  @override
  Future<SettingsLoadResult> load() async {
    return SettingsLoadResult(settings: settings);
  }

  @override
  Future<SettingsSaveResult> save(AppSettings value) async {
    settings = value;
    saveCalls++;
    return saveResult;
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'first launch completes setup and starts once without requesting permission',
    () async {
      final tutorial = _FakeTutorialPreferences();
      final store = _FakeSettingsStore(AppSettings.defaults);
      var running = false;
      var starts = 0;
      var permissionRequests = 0;
      final coordinator = AppStartupCoordinator(
        tutorialPreferences: tutorial,
        settingsStore: store,
        isMonitoringRunning: () async => running,
        requestNotificationPermission: () async {
          permissionRequests++;
          return NotificationPermission.granted;
        },
        startMonitoring: () async {
          starts++;
          running = true;
          return const MonitoringActionResult(
            success: true,
            isRunning: true,
            notificationPermission: NotificationPermission.granted,
          );
        },
      );

      expect(await coordinator.hasCompletedTutorial(), isFalse);
      expect(starts, 0);

      final result = await coordinator.completeFirstLaunch();

      expect(tutorial.completed, isTrue);
      expect(tutorial.completionWrites, 1);
      expect(store.settings.monitoringEnabled, isTrue);
      expect(store.settings.alertsEnabled, isTrue);
      expect(permissionRequests, 0);
      expect(starts, 1);
      expect(result.isRunning, isTrue);
    },
  );

  test(
    'later launches restore once and do not duplicate a running service',
    () async {
      final store = _FakeSettingsStore(AppSettings.defaults);
      var running = false;
      var starts = 0;
      final coordinator = AppStartupCoordinator(
        tutorialPreferences: _FakeTutorialPreferences(completed: true),
        settingsStore: store,
        isMonitoringRunning: () async => running,
        startMonitoring: () async {
          starts++;
          running = true;
          return const MonitoringActionResult(
            success: true,
            isRunning: true,
            notificationPermission: NotificationPermission.granted,
          );
        },
      );

      await coordinator.restoreAfterCompletedTutorial();
      await coordinator.restoreAfterCompletedTutorial();

      expect(starts, 1);
      expect(running, isTrue);
    },
  );

  test('disabled users do not start monitoring', () async {
    final store = _FakeSettingsStore(
      AppSettings.defaults.copyWith(monitoringEnabled: false),
    );
    var starts = 0;
    final coordinator = AppStartupCoordinator(
      tutorialPreferences: _FakeTutorialPreferences(completed: true),
      settingsStore: store,
      isMonitoringRunning: () async => false,
      startMonitoring: () async {
        starts++;
        return const MonitoringActionResult(success: true, isRunning: true);
      },
    );

    final result = await coordinator.restoreAfterCompletedTutorial();

    expect(starts, 0);
    expect(result.monitoringEnabled, isFalse);
    expect(result.isRunning, isFalse);
  });

  test(
    'failed stale-service stop persists the accurate running state',
    () async {
      final store = _FakeSettingsStore(
        AppSettings.defaults.copyWith(monitoringEnabled: false),
      );
      var stopCalls = 0;
      final coordinator = AppStartupCoordinator(
        tutorialPreferences: _FakeTutorialPreferences(completed: true),
        settingsStore: store,
        isMonitoringRunning: () async => true,
        stopMonitoring: () async {
          stopCalls++;
          return const MonitoringActionResult(
            success: false,
            isRunning: true,
            error: 'Android rejected stop',
          );
        },
      );

      final result = await coordinator.restoreAfterCompletedTutorial();

      expect(stopCalls, 1);
      expect(result.monitoringEnabled, isTrue);
      expect(result.isRunning, isTrue);
      expect(store.settings.monitoringEnabled, isTrue);
      expect(result.warning, contains('remains enabled'));
    },
  );

  test(
    'failed automatic start persists the corrected disabled state',
    () async {
      final store = _FakeSettingsStore(AppSettings.defaults);
      final coordinator = AppStartupCoordinator(
        tutorialPreferences: _FakeTutorialPreferences(completed: true),
        settingsStore: store,
        isMonitoringRunning: () async => false,
        startMonitoring: () async => const MonitoringActionResult(
          success: false,
          isRunning: false,
          error: 'Foreground service unavailable',
        ),
      );

      final result = await coordinator.restoreAfterCompletedTutorial();

      expect(result.monitoringEnabled, isFalse);
      expect(store.settings.monitoringEnabled, isFalse);
      expect(result.warning, contains('Open Settings'));
    },
  );

  test(
    'permission denial warns without stopping phone-angle monitoring',
    () async {
      final store = _FakeSettingsStore(AppSettings.defaults);
      final coordinator = AppStartupCoordinator(
        tutorialPreferences: _FakeTutorialPreferences(),
        settingsStore: store,
        isMonitoringRunning: () async => false,
        requestNotificationPermission: () async =>
            NotificationPermission.denied,
        startMonitoring: () async => const MonitoringActionResult(
          success: true,
          isRunning: true,
          notificationPermission: NotificationPermission.denied,
        ),
      );

      final result = await coordinator.completeFirstLaunch();

      expect(result.monitoringEnabled, isTrue);
      expect(result.isRunning, isTrue);
      expect(result.warning, contains('notification permission is disabled'));
    },
  );

  test('cloud failure keeps the locally selected enabled defaults', () async {
    final store = _FakeSettingsStore(
      AppSettings.defaults,
      saveResult: const SettingsSaveResult(
        savedLocally: true,
        savedToFirebase: false,
      ),
    );
    final coordinator = AppStartupCoordinator(
      tutorialPreferences: _FakeTutorialPreferences(),
      settingsStore: store,
      isMonitoringRunning: () async => false,
      requestNotificationPermission: () async => NotificationPermission.granted,
      startMonitoring: () async => const MonitoringActionResult(
        success: true,
        isRunning: true,
        notificationPermission: NotificationPermission.granted,
      ),
    );

    final result = await coordinator.completeFirstLaunch();

    expect(store.settings.monitoringEnabled, isTrue);
    expect(store.settings.alertsEnabled, isTrue);
    expect(result.warning, contains('cloud synchronization failed'));
  });
}
